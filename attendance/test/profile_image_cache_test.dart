import 'dart:convert';
import 'dart:io';

import 'package:attendance/services/profile_image_cache.dart';
import 'package:attendance/widgets/profile_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
      final manager = cached.cacheManager! as CacheManager;
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
      expect(manager.config.maxNrOfCacheObjects, 80);
      expect(manager.config.stalePeriod, const Duration(days: 1));
      await ProfileImageCache.clearViewer('cache-test-viewer');
      expect(await manager.getFileFromCache(next.cacheKey!), isNull);
    },
  );
}
