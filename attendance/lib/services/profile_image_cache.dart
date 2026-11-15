import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Private profile media uses viewer-scoped disk and decoded-image keys.
class ProfileImageCache {
  static final _viewers = <String, CacheManager>{};
  static final _decoded =
      <String, Map<(String, int?), ImageProvider<Object>>>{};

  /// Uploads have unique filenames; only the expiring signature is ignored.
  static String key(String url, {required String viewer, String? office}) {
    final uri = Uri.parse(url);
    final version =
        uri.path.startsWith('/storage/v1/object/sign/profile-media/')
        ? uri.replace(query: '').toString()
        : url;
    return '$viewer:${office ?? "profile"}:$version';
  }

  static ImageProvider<Object> image(
    String url, {
    required String viewer,
    String? office,
    int? width,
  }) {
    final manager = _viewers.putIfAbsent(
      viewer,
      () => CacheManager(
        Config(
          'profile-media-v1-$viewer',
          stalePeriod: const Duration(days: 1),
          maxNrOfCacheObjects: 80,
        ),
      ),
    );
    // Resize only when decoding: disk resizing would flatten animated GIFs.
    final cacheKey = key(url, viewer: viewer, office: office);
    final image = ResizeImage.resizeIfNeeded(
      width,
      null,
      CachedNetworkImageProvider(
        url,
        cacheKey: cacheKey,
        cacheManager: manager,
      ),
    );
    (_decoded[viewer] ??= {})[(cacheKey, width)] = image;
    return image;
  }

  /// Called when the account-scoped profile provider is removed on sign-out.
  static Future<void> clearViewer(String viewer) async {
    try {
      final decoded = _decoded.remove(viewer) ?? {};
      for (final image in decoded.values) {
        await image.evict();
      }
      await _viewers[viewer]?.emptyCache();
    } catch (_) {
      // Cache cleanup must not prevent signing out (e.g. OS removed temp files).
    }
  }
}
