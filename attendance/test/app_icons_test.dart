import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared artwork uses the package outline font', () {
    for (final icon in [
      AppIcons.home,
      AppIcons.clock,
      AppIcons.shield,
      AppIcons.user,
      AppIcons.bellRinging,
      AppIcons.check,
      AppIcons.x,
      AppIcons.fingerprint,
    ]) {
      expect(icon.fontFamily, 'tabler-icons');
      expect(icon.fontPackage, 'tabler_icons_plus');
    }
  });

  for (final theme in [AppTheme.theme, AppTheme.darkTheme]) {
    testWidgets('default icons are gray and 24px in ${theme.brightness.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: Icon(AppIcons.home)),
        ),
      );
      final context = tester.element(find.byIcon(AppIcons.home));
      expect(IconTheme.of(context).size, 24);
      expect(IconTheme.of(context).color, theme.colorScheme.onSurfaceVariant);
      final back =
          Theme.of(context).actionIconTheme!.backButtonIconBuilder!(context)
              as Icon;
      expect(back.icon, AppIcons.chevronLeft);
    });
  }
}
