import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Loads licensed Inter fixtures without networking or changing app assets.
Future<void> loadOverviewFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  const codec = StandardMessageCodec();
  final manifest = Map<Object?, Object?>.from(
    codec.decodeMessage(await rootBundle.load('AssetManifest.bin'))! as Map,
  );
  final bytes = await File(
    'test/support/fonts/InterVariable.ttf',
  ).readAsBytes();
  final fontData = ByteData.sublistView(bytes);
  final names = [
    for (final variant in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'test-fonts/Inter-$variant.ttf',
  ];
  for (final name in names) {
    manifest[name] = [
      {'asset': name},
    ];
  }
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (message) {
    final key = utf8.decode(
      message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes),
    );
    if (key == 'AssetManifest.bin') {
      return Future.value(codec.encodeMessage(manifest));
    }
    if (names.contains(key)) return Future.value(fontData);
    return messenger.delegate.send('flutter/assets', message);
  });
  try {
    for (final weight in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
    ]) {
      GoogleFonts.inter(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
  } finally {
    messenger.setMockMessageHandler('flutter/assets', null);
  }
}
