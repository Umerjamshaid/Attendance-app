import 'dart:async';
import 'dart:typed_data';

import 'package:file/file.dart' show File;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

import '../models/signed_profile_url.dart';

typedef ProfileUrlRefresh = Future<String?> Function(String url);

/// One login's cache access. A later login waits for retirement before opening
/// the same persistent directory, but never shares this manager or image keys.
class ProfileCacheSession implements BaseCacheManager {
  ProfileCacheSession(
    String viewer, {
    Future<String>? after,
    http.Client? client,
    CacheManager Function(Config)? createManager,
  }) : _client = client ?? http.Client() {
    _manager = () async {
      cacheNamespace = await after ?? 'profile-media-v1-$viewer';
      _files = _TrackedFiles(IOFileSystem(cacheNamespace));
      return (createManager ?? CacheManager.new)(
        Config(
          cacheNamespace,
          stalePeriod: const Duration(days: 1),
          maxNrOfCacheObjects: 80,
          fileSystem: _files,
          fileService: _MediaFileService(_client, () => _retired),
        ),
      );
    }();
  }

  final http.Client _client;
  late final String cacheNamespace;
  late final _TrackedFiles _files;
  late final Future<CacheManager> _manager;
  final _pending = <Future<void>>{};
  final _refreshers = <String, ProfileUrlRefresh>{};
  bool _retired = false;
  Future<void>? _retirement;
  @visibleForTesting
  int get unindexedFileCount => _files.created.length;
  void register(String key, ProfileUrlRefresh? refresh) {
    if (!_retired && refresh != null) _refreshers[key] = refresh;
  }

  Future<T> _run<T>(Future<T> Function(CacheManager) operation) async {
    if (_retired) throw StateError('The image session has ended.');
    final done = Completer<void>();
    _pending.add(done.future);
    try {
      final manager = await _manager;
      if (_retired) throw StateError('The image session has ended.');
      final result = await operation(manager);
      if (result is FileInfo) _files.indexed(result.file);
      if (result is File) _files.indexed(result);
      return result;
    } finally {
      _pending.remove(done.future);
      done.complete();
    }
  }

  Future<String> _resolve(
    CacheManager manager,
    String url,
    String key, {
    bool force = false,
  }) async {
    if (_retired) throw StateError('The image session has ended.');
    final refresh = _refreshers[key];
    if (refresh == null) return url;
    final cached = await manager.getFileFromCache(key);
    final present = cached != null && await cached.file.exists();
    if (cached != null && !present) await manager.removeFile(key);
    if (!force && present && cached.validTill.isAfter(DateTime.now())) {
      return url;
    }
    if (!force && !SignedProfileUrl.fromUrl(url).needsRefresh(DateTime.now())) {
      return url;
    }
    String? renewed;
    try {
      renewed = await refresh(url);
    } catch (_) {
      if (!_retired && present) return url;
      rethrow;
    }
    if (_retired || renewed == null) {
      throw StateError('The image is no longer available.');
    }
    return renewed;
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    final cacheKey = key ?? url;
    late final StreamController<FileResponse> output;
    output = StreamController<FileResponse>(
      onListen: () {
        // Keep draining after widget cancellation: final cleanup must wait until
        // CacheManager has finished writing, not just until its consumer leaves.
        unawaited(() async {
          try {
            await _run((manager) async {
              var current = await _resolve(manager, url, cacheKey);
              for (var attempt = 0; attempt < 2; attempt++) {
                try {
                  await for (final event in manager.getFileStream(
                    current,
                    key: cacheKey,
                    headers: headers,
                    withProgress: withProgress,
                  )) {
                    if (event is FileInfo) _files.indexed(event.file);
                    if (!_retired && output.hasListener) output.add(event);
                  }
                  return;
                } on HttpExceptionWithStatus catch (error) {
                  if (attempt != 0 ||
                      ![400, 401, 403].contains(error.statusCode) ||
                      !_refreshers.containsKey(cacheKey)) {
                    rethrow;
                  }
                  current = await _resolve(
                    manager,
                    current,
                    cacheKey,
                    force: true,
                  );
                }
              }
            });
          } catch (error, stack) {
            if (output.hasListener) output.addError(error, stack);
          } finally {
            unawaited(output.close());
          }
        }());
      },
    );
    return output.stream;
  }

  Future<void> retire() {
    if (_retirement != null) return _retirement!;
    _retired = true;
    _client.close();
    return _retirement = () async {
      await Future.wait(_pending.toList());
      final manager = await _manager;
      try {
        await manager.emptyCache();
      } finally {
        try {
          // Interrupted transfers may leave files not yet indexed by CacheManager.
          for (final file in _files.created.values) {
            if (await file.exists()) await file.delete();
          }
        } finally {
          _files.created.clear();
          _refreshers.clear();
          await manager.dispose();
        }
      }
    }();
  }

  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async => (await getFileStream(
    url,
    key: key,
    headers: headers,
  ).where((e) => e is FileInfo).cast<FileInfo>().first).file;
  @override
  Stream<FileInfo> getFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) => getFileStream(
    url,
    key: key,
    headers: headers,
  ).where((e) => e is FileInfo).cast<FileInfo>();
  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) => _run(
    (manager) async => manager.downloadFile(
      await _resolve(manager, url, key ?? url, force: force),
      key: key,
      authHeaders: authHeaders,
      force: force,
    ),
  );
  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) => _retired
      ? Future.value(null)
      : _run((m) => m.getFileFromCache(key, ignoreMemCache: ignoreMemCache));
  @override
  Future<FileInfo?> getFileFromMemory(String key) =>
      _retired ? Future.value(null) : _run((m) => m.getFileFromMemory(key));
  @override
  Future<File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) => _run(
    (m) => m.putFile(
      url,
      fileBytes,
      key: key,
      eTag: eTag,
      maxAge: maxAge,
      fileExtension: fileExtension,
    ),
  );
  @override
  Future<File> putFileStream(
    String url,
    Stream<List<int>> source, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) => _run(
    (m) => m.putFileStream(
      url,
      source,
      key: key,
      eTag: eTag,
      maxAge: maxAge,
      fileExtension: fileExtension,
    ),
  );
  @override
  Future<void> removeFile(String key) => _run((m) => m.removeFile(key));
  @override
  Future<void> emptyCache() => _run((m) => m.emptyCache());
  @override
  Future<void> dispose() => retire();
}

class _TrackedFiles implements FileSystem {
  _TrackedFiles(this.delegate);
  final FileSystem delegate;
  final created = <String, File>{};
  void indexed(File file) => created.remove(file.path);
  @override
  Future<File> createFile(String name) async {
    final file = await delegate.createFile(name);
    if (!await file.exists()) created[file.path] = file;
    return file;
  }
}

class _MediaFileService extends HttpFileService {
  _MediaFileService(http.Client client, this.isRetired)
    : super(httpClient: client);
  final bool Function() isRetired;
  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await super
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 30));
    if (isRetired()) throw StateError('The image session has ended.');
    return _BoundedResponse(response, isRetired);
  }
}

class _BoundedResponse implements FileServiceResponse {
  _BoundedResponse(this.delegate, this.isRetired);
  final FileServiceResponse delegate;
  final bool Function() isRetired;
  @override
  Stream<List<int>> get content async* {
    await for (final bytes in delegate.content.timeout(
      const Duration(seconds: 30),
    )) {
      if (isRetired()) throw StateError('The image session has ended.');
      yield bytes;
    }
  }

  @override
  int? get contentLength => delegate.contentLength;
  @override
  int get statusCode => delegate.statusCode;
  @override
  DateTime get validTill => delegate.validTill;
  @override
  String? get eTag => delegate.eTag;
  @override
  String get fileExtension => delegate.fileExtension;
}
