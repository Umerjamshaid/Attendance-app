import 'dart:typed_data';

import 'package:mime/mime.dart';

import 'company_backend.dart';

/// Profile-only formats; attendance evidence keeps its separate validation.
enum ProfileImageFormat {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  gif('image/gif', 'gif'),
  webp('image/webp', 'webp'),
  bmp('image/bmp', 'bmp');

  const ProfileImageFormat(this.contentType, this.extension);

  final String contentType;
  final String extension;

  static const maxBytes = 2 * 1024 * 1024;
  static final _mimeTypes = MimeTypeResolver()
    ..addMagicNumber([0x42, 0x4d], 'image/bmp');

  /// Identifies the actual bytes rather than trusting a file's extension.
  static ProfileImageFormat fromBytes(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const CompanyException('Choose an image no larger than 2 MB.');
    }
    final contentType = _mimeTypes.lookup('', headerBytes: bytes);
    for (final format in values) {
      if (format.contentType == contentType) return format;
    }
    throw const CompanyException(
      'Choose a JPEG, PNG, GIF, WebP, or BMP image.',
    );
  }
}
