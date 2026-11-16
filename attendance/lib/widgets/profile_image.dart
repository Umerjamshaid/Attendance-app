import 'dart:io';
import 'package:flutter/material.dart';
import '../services/profile_image_cache.dart';
import '../services/profile_cache_session.dart';

String profileImageIdentity(String path, {String? viewer}) =>
    viewer == null ? path : ProfileImageCache.key(path, viewer: viewer);

ImageProvider<Object> profileImageProvider(
  String path, {
  String? viewer,
  String? office,
  int? width,
  ProfileUrlRefresh? refresh,
}) {
  if (path.startsWith('https://')) {
    if (viewer != null && viewer.isNotEmpty) {
      return ProfileImageCache.image(
        path,
        viewer: viewer,
        office: office,
        width: width,
        refresh: refresh,
      );
    }
    return ResizeImage.resizeIfNeeded(width, null, NetworkImage(path));
  }
  return ResizeImage.resizeIfNeeded(width, null, FileImage(File(path)));
}
