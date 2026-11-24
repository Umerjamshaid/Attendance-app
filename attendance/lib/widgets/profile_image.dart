import 'dart:io';

import 'package:flutter/material.dart';

import '../services/profile_image_cache.dart';
import '../services/profile_cache_session.dart';

/// Paints decoded cache hits immediately and fades in the first cold frame.
ImageFrameBuilder profileImageFrame(Widget placeholder) =>
    (context, child, frame, wasSync) {
      if (wasSync) return child;
      if (MediaQuery.disableAnimationsOf(context)) {
        return frame == null ? placeholder : child;
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          placeholder,
          AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 160),
            child: child,
          ),
        ],
      );
    };

String profileImageIdentity(String path, {String? viewer}) =>
    viewer == null ? path : ProfileImageCache.key(path, viewer: viewer);

/// Converts a thumbnail's logical width to its decode width in physical pixels.
int profileDecodeWidth(BuildContext context, double logicalWidth) =>
    (logicalWidth * MediaQuery.devicePixelRatioOf(context)).ceil();

/// Share the largest small office avatar decode across roster, roles and logs.
const double officeEmployeeThumbnailSize = 48;

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
