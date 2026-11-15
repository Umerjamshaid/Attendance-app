import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:attendance/services/profile_image_cache.dart';
import 'package:attendance/services/profile_cache_session.dart';
import 'package:attendance/models/signed_profile_url.dart';
import 'package:attendance/widgets/profile_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const _url =
    'https://photos.example.invalid/storage/v1/object/sign/profile-media/owner/avatar-v1.gif?token=old';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String> getTemporaryPath() async => path;
  @override
  Future<String> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cache keys follow file versions, not refreshed private signatures', () {
    String key(
      String url, {
      String viewer = 'viewer',
      String office = 'office-a',
    }) => ProfileImageCache.key(url, viewer: viewer, office: office);
    expect(key(_url), key(_url.replaceFirst('token=old', 'token=new')));
    expect(key(_url), isNot(key(_url.replaceFirst('v1.gif', 'v2.png'))));
    expect(key(_url), isNot(key(_url, viewer: 'other-viewer')));
    expect(key(_url), isNot(key(_url, office: 'office-b')));
    expect(
      key(_url),
      isNot(key(_url.replaceFirst('photos.example', 'other.example'))),
    );
    expect(
      key('https://example.invalid/avatar?version=1'),
      isNot(key('https://example.invalid/avatar?version=2')),
    );
    expect(profileImageProvider('local.gif'), isA<FileImage>());
    expect(
      profileImageProvider(_url),
      isA<NetworkImage>(),
      reason: 'Anonymous and legacy URLs do not enter the private disk cache',
    );
  });

  test('an offline signing refresh does not discard a cached GIF', () async {
    final directory = await Directory.systemTemp.createTemp(
      'attendance-offline-gif-',
    );
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    addTearDown(() async {
      PathProviderPlatform.instance = original;
      await directory.delete(recursive: true);
    });
    final image =
        ProfileImageCache.image(
              _url,
              viewer: 'offline-gif',
              refresh: (_) async => throw const SocketException('Offline'),
              httpClient: MockClient(
                (_) async => http.Response('unavailable', 503),
              ),
            )
            as CachedNetworkImageProvider;
    final manager = image.cacheManager!;
    final gif = base64Decode(
      'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
    );
    await manager.putFile(
      _url,
      gif,
      key: image.cacheKey,
      maxAge: const Duration(seconds: -1),
      fileExtension: 'gif',
    );
    final file = await manager.getSingleFile(_url, key: image.cacheKey!);
    expect(await file.readAsBytes(), gif);
    await ProfileImageCache.clearViewer('offline-gif');
  });

  test(
    'expiry metadata is optional, typed and never an authorization decision',
    () {
      String signed(Object? payload) => _url.replaceFirst(
        'old',
        'header.${base64Url.encode(utf8.encode(jsonEncode(payload)))}.signature',
      );
      for (final payload in [
        null,
        [],
        {'exp': 'tomorrow'},
        {'exp': -1},
        {'exp': 1e300},
      ]) {
        expect(SignedProfileUrl.fromUrl(signed(payload)).expiresAt, isNull);
      }
      expect(
        SignedProfileUrl.fromUrl(_url).needsRefresh(DateTime.now()),
        isTrue,
      );
      expect(
        SignedProfileUrl.fromUrl(
          'https://example.invalid/public.gif',
        ).needsRefresh(DateTime.now()),
        isFalse,
      );
    },
  );

  test(
    'a rejected download re-signs once and retries rather than sticking on initials',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'attendance-download-retry-',
      );
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = original;
        await directory.delete(recursive: true);
      });
      String token =
          'header.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})))}.signature';
      final initial = _url.replaceFirst('old', token);
      final renewed = initial.replaceFirst('signature', 'renewed-signature');
      final calls = <String>[];
      var refreshes = 0;
      final image =
          ProfileImageCache.image(
                initial,
                viewer: 'retry-viewer',
                refresh: (url) async {
                  refreshes++;
                  return renewed;
                },
                httpClient: MockClient((request) async {
                  calls.add(request.url.toString());
                  return calls.length == 1
                      ? http.Response('expired', 403)
                      : http.Response(
                          'original-gif',
                          200,
                          headers: {
                            'content-type': 'image/gif',
                            'cache-control': 'max-age=3600',
                          },
                        );
                }),
              )
              as CachedNetworkImageProvider;
      final file = await image.cacheManager!.getSingleFile(
        initial,
        key: image.cacheKey!,
      );
      expect(await file.readAsString(), 'original-gif');
      expect(calls, [initial, renewed]);
      expect(refreshes, 1);
      await ProfileImageCache.clearViewer('retry-viewer');
    },
  );

  test(
    'rotated URLs reuse original GIF bytes; sign-out removes disk entries',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'attendance-image-cache-test-',
      );
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      final image =
          profileImageProvider(_url, viewer: 'cache-test-viewer', width: 120)
              as ResizeImage;
      final cached = image.imageProvider as CachedNetworkImageProvider;
      final manager = cached.cacheManager! as ProfileCacheSession;
      addTearDown(() async {
        await manager.dispose();
        PathProviderPlatform.instance = original;
        await directory.delete(recursive: true);
      });
      final gif = base64Decode(
        'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
      );
      await manager.putFile(
        _url,
        gif,
        key: cached.cacheKey,
        maxAge: const Duration(hours: 1),
        fileExtension: 'gif',
      );
      final rotated =
          profileImageProvider(
                _url.replaceFirst('old', 'new'),
                viewer: 'cache-test-viewer',
                width: 120,
              )
              as ResizeImage;
      final next = rotated.imageProvider as CachedNetworkImageProvider;
      expect(
        await image.obtainKey(ImageConfiguration.empty),
        await rotated.obtainKey(ImageConfiguration.empty),
        reason: 'decoded images also survive signature rotation',
      );
      expect(
        next.maxWidth,
        isNull,
        reason: 'disk resizing must not flatten GIFs',
      );
      expect(identical(cached.cacheManager, next.cacheManager), isTrue);
      final hit = await manager.getSingleFile(next.url, key: next.cacheKey);
      expect(await hit.readAsBytes(), gif);
      expect(image.width, 120);
      await ProfileImageCache.clearViewer('cache-test-viewer');
      expect(await manager.getFileFromCache(next.cacheKey!), isNull);
    },
  );

  test(
    'clearViewer waits for a late download and isolates a subsequent login',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'attendance-retirement-test-',
      );
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = original;
        await directory.delete(recursive: true);
      });
      final started = Completer<void>();
      final delayed = Completer<http.Response>();
      final oldImage =
          ProfileImageCache.image(
                _url,
                viewer: 'late-viewer',
                httpClient: MockClient((request) {
                  started.complete();
                  return delayed.future;
                }),
              )
              as CachedNetworkImageProvider;
      final old = oldImage.cacheManager!;
      final events = <FileResponse>[];
      final finished = Completer<void>();
      old
          .getFileStream(_url, key: oldImage.cacheKey!)
          .listen(
            events.add,
            onError: (Object _) {},
            onDone: finished.complete,
          );
      await started.future;
      final cleanup = ProfileImageCache.clearViewer('late-viewer');
      final newImage =
          ProfileImageCache.image(
                _url,
                viewer: 'late-viewer',
                httpClient: MockClient(
                  (request) async => http.Response(
                    'new-login-bytes',
                    200,
                    headers: {
                      'content-type': 'image/gif',
                      'cache-control': 'max-age=3600',
                    },
                  ),
                ),
              )
              as CachedNetworkImageProvider;
      expect(identical(oldImage.cacheManager, newImage.cacheManager), isFalse);
      expect(
        await oldImage.obtainKey(ImageConfiguration.empty),
        isNot(await newImage.obtainKey(ImageConfiguration.empty)),
      );
      delayed.complete(
        http.Response(
          'old-private-image',
          200,
          headers: {
            'content-type': 'image/gif',
            'cache-control': 'max-age=3600',
          },
        ),
      );
      await cleanup;
      await finished.future;
      expect(events.whereType<FileInfo>(), isEmpty);
      final current = newImage.cacheManager!;
      expect(
        await current.getFileFromCache(newImage.cacheKey!),
        isNull,
        reason:
            'late old-session bytes are removed before the new manager opens',
      );
      final file = await current.getSingleFile(_url, key: newImage.cacheKey!);
      expect(await file.readAsString(), 'new-login-bytes');
      await old.dispose();
      expect(
        await file.exists(),
        isTrue,
        reason: 'old retirement cannot delete new-login files',
      );
      await ProfileImageCache.clearViewer('late-viewer');
    },
  );

  test(
    'an uncached image is re-signed before a download after its 60-second URL expires',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'attendance-url-refresh-test-',
      );
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = original;
        await directory.delete(recursive: true);
      });
      String token(DateTime expires) =>
          'header.${base64Url.encode(utf8.encode(jsonEncode({'exp': expires.millisecondsSinceEpoch ~/ 1000}))).replaceAll('=', '')}.signature';
      final expired = _url.replaceFirst(
        'token=old',
        'token=${token(DateTime.now().subtract(const Duration(seconds: 1)))}',
      );
      final fresh = _url.replaceFirst(
        'token=old',
        'token=${token(DateTime.now().add(const Duration(minutes: 15)))}',
      );
      expect(
        SignedProfileUrl.fromUrl(expired).needsRefresh(DateTime.now()),
        isTrue,
      );
      final downloads = <String>[];
      var resigns = 0;
      final image =
          ProfileImageCache.image(
                expired,
                viewer: 'expired-viewer',
                refresh: (url) async {
                  resigns++;
                  return fresh;
                },
                httpClient: MockClient((request) async {
                  downloads.add(request.url.toString());
                  return http.Response(
                    'gif-bytes',
                    200,
                    headers: {
                      'content-type': 'image/gif',
                      'cache-control': 'max-age=3600',
                    },
                  );
                }),
              )
              as CachedNetworkImageProvider;
      final manager = image.cacheManager!;
      await manager.getSingleFile(expired, key: image.cacheKey!);
      expect(downloads, [fresh]);
      expect(resigns, 1);
      await manager.getSingleFile(expired, key: image.cacheKey!);
      expect(
        downloads.length,
        1,
        reason:
            'returning to the sheet uses cached bytes without a new URL or download',
      );
      await ProfileImageCache.clearViewer('expired-viewer');
    },
  );
}
