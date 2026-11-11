import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Uses the SDK's fallback fonts rather than the test runner's block font.
Future<void> loadTestFonts() async {
  final config = File('.dart_tool/package_config.json');
  final packages =
      (jsonDecode(await config.readAsString())
              as Map<String, dynamic>)['packages']
          as List<dynamic>;
  final flutter = packages.cast<Map<String, dynamic>>().firstWhere(
    (package) => package['name'] == 'flutter',
  );
  final fonts = config.uri
      .resolve('${flutter['rootUri']}/')
      .resolve('../../bin/cache/artifacts/material_fonts/');
  for (final entry in {
    'Roboto': 'roboto-regular.ttf',
    'MaterialIcons': 'materialicons-regular.otf',
  }.entries) {
    final loader = FontLoader(entry.key)
      ..addFont(
        File.fromUri(
          fonts.resolve(entry.value),
        ).readAsBytes().then(ByteData.sublistView),
      );
    await loader.load();
  }
  await (FontLoader('packages/tabler_icons_plus/tabler-icons')..addFont(
        rootBundle.load(
          'packages/tabler_icons_plus/lib/fonts/tabler-icons.ttf',
        ),
      ))
      .load();
  await (FontLoader(
    'DM Sans',
  )..addFont(rootBundle.load('assets/fonts/DMSans.ttf'))).load();
}
