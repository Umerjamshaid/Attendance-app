import 'dart:typed_data';
import 'dart:ui' as ui;

/// Solid colors use the existing PNG banner storage and access rules.
Future<Uint8List> bannerColorPng(ui.Color color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(color.withValues(alpha: 1), ui.BlendMode.src);
  final picture = recorder.endRecording();
  ui.Image? image;
  try {
    image = await picture.toImage(16, 16);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Could not create the banner color.');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image?.dispose();
    picture.dispose();
  }
}
