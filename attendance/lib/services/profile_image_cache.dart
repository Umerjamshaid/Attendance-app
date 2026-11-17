import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'profile_cache_session.dart';
import 'profile_cache_cleanup.dart';

/// Private profile media uses viewer-scoped disk and decoded-image keys.
class ProfileImageCache {
  static final _viewers = <String, ProfileCacheSession>{};
  static final _retiring = <String, Future<String>>{};
  static final _cleanup = ProfileCacheCleanup();
  static final _decoded =
      <String, Map<(String, int?), ImageProvider<Object>>>{};

  /// Uploads have unique filenames; only the expiring signature is ignored.
  static String key(String url, {required String viewer, String? office}) {
    final uri = Uri.parse(url);
    final version =
        (uri.path.startsWith('/storage/v1/object/sign/profile-media/') ||
            uri.path.startsWith('/storage/v1/object/sign/office-logos/'))
        ? uri.replace(query: '').toString()
        : url;
    return '$viewer:${office ?? "profile"}:$version';
  }

  static ImageProvider<Object> image(
    String url, {
    required String viewer,
    String? office,
    int? width,
    ProfileUrlRefresh? refresh,
    http.Client? httpClient,
    CacheManager Function(Config)? createManager,
  }) {
    unawaited(retryFailedCleanups());
    final manager = _viewers.putIfAbsent(
      viewer,
      () => ProfileCacheSession(
        viewer,
        after: _retiring[viewer] ?? _cleanup.namespaceFor(viewer),
        client: httpClient,
        createManager: createManager,
      ),
    );
    // Resize only when decoding: disk resizing would flatten animated GIFs.
    final cacheKey = key(url, viewer: viewer, office: office);
    manager.register(cacheKey, refresh);
    final image = ResizeImage.resizeIfNeeded(
      width,
      null,
      _SessionImageProvider(url, cacheKey: cacheKey, cacheManager: manager),
    );
    (_decoded[viewer] ??= {})[(cacheKey, width)] = image;
    return image;
  }

  /// Explicit retry discards a possibly corrupt file and its decoded variants.
  static Future<void> removeImage(String url, {required String viewer}) async {
    final cacheKey = key(url, viewer: viewer);
    final decoded = _decoded[viewer];
    final matches =
        decoded?.keys.where((entry) => entry.$1 == cacheKey).toList() ?? [];
    for (final entry in matches) {
      await decoded!.remove(entry)!.evict();
    }
    await _viewers[viewer]?.removeFile(cacheKey);
  }

  /// Called when the account-scoped profile provider is removed on sign-out.
  static Future<void> clearViewer(String viewer) async {
    final manager = _viewers.remove(viewer);
    final retirement = manager == null
        ? _retiring[viewer]
        : manager.retire().then((_) => manager.cacheNamespace).catchError((
            Object _,
          ) async {
            await _cleanup.remember(manager.cacheNamespace);
            return ProfileCacheCleanup.freshNamespace(viewer);
          });
    if (retirement != null) _retiring[viewer] = retirement;
    try {
      final decoded = _decoded.remove(viewer) ?? {};
      for (final image in decoded.values) {
        await image.evict();
      }
      await retirement;
    } catch (_) {
      // Cache cleanup must not prevent signing out (e.g. OS removed temp files).
    }
    unawaited(retryFailedCleanups());
  }

  static Future<void> retryFailedCleanups() => _cleanup.retry();
}

// CachedNetworkImageProvider normally ignores its manager in memory-cache keys.
// Keep a later login separate even if it requests the very same object URL.
class _SessionImageProvider extends CachedNetworkImageProvider {
  const _SessionImageProvider(
    super.url, {
    super.cacheKey,
    required ProfileCacheSession super.cacheManager,
  });
  @override
  bool operator ==(Object other) =>
      other is _SessionImageProvider &&
      identical(cacheManager, other.cacheManager) &&
      super == other;
  @override
  int get hashCode =>
      Object.hash(super.hashCode, identityHashCode(cacheManager));
}
