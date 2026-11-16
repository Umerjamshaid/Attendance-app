import 'dart:io' as io;

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable, best-effort retries for retired private-image cache namespaces.
class ProfileCacheCleanup {
  ProfileCacheCleanup({Future<void> Function(String)? purge})
    : _purge = purge ?? _purgeNamespace;

  static const pendingKey = 'profile-media-pending-purges-v1';
  static final _validNamespace = RegExp(r'^profile-media-v1-[A-Za-z0-9-]+$');
  static int _recoveryId = 0;
  final Future<void> Function(String) _purge;
  final _pending = <String>{};
  bool _loaded = false;
  Future<bool>? _loading;
  Future<void>? _running;
  Future<void> _writing = Future.value();

  static String _base(String viewer) {
    final name = 'profile-media-v1-$viewer';
    if (!_validNamespace.hasMatch(name)) throw ArgumentError.value(viewer);
    return name;
  }

  static String freshNamespace(String viewer) =>
      '${_base(viewer)}-recovery-${DateTime.now().microsecondsSinceEpoch}-${_recoveryId++}';

  Future<String> namespaceFor(String viewer) async {
    final name = _base(viewer);
    final loaded = await _load();
    return !loaded || _pending.contains(name) ? freshNamespace(viewer) : name;
  }

  Future<void> remember(String name) async {
    if (!_validNamespace.hasMatch(name)) return;
    await _load();
    _pending.add(name);
    await _persist();
  }

  Future<bool> _load() async {
    if (_loaded) return true;
    if (_loading != null) return _loading!;
    final request = () async {
      try {
        final prefs = await SharedPreferences.getInstance().timeout(
          const Duration(seconds: 5),
        );
        _pending.addAll(
          (prefs.getStringList(pendingKey) ?? []).where(
            _validNamespace.hasMatch,
          ),
        );
        return _loaded = true;
      } catch (_) {
        return false;
      }
    }();
    _loading = request;
    try {
      return await request;
    } finally {
      if (identical(_loading, request)) _loading = null;
    }
  }

  Future<void> _persist() => _writing = _writing
      .then((_) async {
        if (!await _load()) return;
        final prefs = await SharedPreferences.getInstance();
        await prefs
            .setStringList(pendingKey, _pending.toList())
            .timeout(const Duration(seconds: 5));
      })
      .catchError((Object _) {
        // Keep the in-memory queue if preferences are temporarily unwritable too.
      });

  Future<void> retry() {
    if (_running != null) return _running!;
    late final Future<void> task;
    task = _retry().whenComplete(() {
      if (identical(_running, task)) _running = null;
    });
    return _running = task;
  }

  Future<void> _retry() async {
    await _load();
    if (_pending.isEmpty) return;
    await _persist();
    for (final name in _pending.toList()) {
      try {
        await _purge(name);
        _pending.remove(name);
        await _persist();
      } catch (_) {
        // A locked file stays queued, without failing sign-out or image loading.
      }
    }
  }

  static Future<void> _purgeNamespace(String name) async {
    if (!_validNamespace.hasMatch(name)) throw ArgumentError.value(name);
    final files = IOFileSystem(name);
    final directory = (await files.createFile('_cleanup')).parent;
    if (await io.FileSystemEntity.type(directory.path, followLinks: false) !=
        io.FileSystemEntityType.directory) {
      throw const io.FileSystemException('Unsafe profile cache directory');
    }
    final manager = CacheManager(Config(name, fileSystem: files));
    try {
      try {
        await manager.emptyCache();
      } finally {
        // CacheManager only knows indexed files. This exact namespace is retired;
        // also remove flat partial files, without following links or recursing.
        await for (final entry in directory.list(followLinks: false)) {
          if (entry is io.File || entry is io.Link) {
            await entry.delete();
          } else {
            throw const io.FileSystemException(
              'Unexpected profile cache entry',
            );
          }
        }
      }
    } finally {
      await manager.dispose();
    }
  }
}
