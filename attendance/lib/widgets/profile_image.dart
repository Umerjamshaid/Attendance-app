import 'dart:io';
import 'package:flutter/material.dart';
import '../services/profile_image_cache.dart';

ImageProvider<Object> profileImageProvider(
  String path, {
  String? viewer,
  String? office,
  int? width,
}) {
  if (path.startsWith('https://')) {
    if (viewer != null && viewer.isNotEmpty) {
      return ProfileImageCache.image(
        path,
        viewer: viewer,
        office: office,
        width: width,
      );
    }
    return ResizeImage.resizeIfNeeded(width, null, NetworkImage(path));
  }
  return ResizeImage.resizeIfNeeded(width, null, FileImage(File(path)));
}
