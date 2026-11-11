import 'package:attendance/config/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    final theme = dark ? AppTheme.darkTheme : AppTheme.theme;
    final colors = theme.colorScheme;

    test('${dark ? 'dark' : 'light'} uses Petrol and Graphite roles', () {
      expect(
        colors.primary,
        dark ? const Color(0xFF67D5E5) : const Color(0xFF167D8D),
      );
      expect(
        colors.primaryContainer,
        dark ? const Color(0xFF16343A) : const Color(0xFFDFF1F3),
      );
      expect(
        theme.scaffoldBackgroundColor,
        dark ? const Color(0xFF141719) : const Color(0xFFF7F9FA),
      );
      expect(colors.surface, dark ? const Color(0xFF1F2327) : Colors.white);
      expect(theme.appBarTheme.backgroundColor, theme.scaffoldBackgroundColor);
    });

    test('${dark ? 'dark' : 'light'} text pairs retain AA contrast', () {
      final pairs = [
        (colors.onPrimary, colors.primary),
        (colors.onPrimaryContainer, colors.primaryContainer),
        (colors.onSecondary, colors.secondary),
        (colors.onSecondaryContainer, colors.secondaryContainer),
        (colors.onError, colors.error),
        (colors.onErrorContainer, colors.errorContainer),
        (colors.onInverseSurface, colors.inverseSurface),
        (colors.inversePrimary, colors.inverseSurface),
        for (final surface in [
          theme.scaffoldBackgroundColor,
          colors.surface,
          colors.surfaceContainerLow,
          colors.surfaceContainer,
          colors.surfaceContainerHighest,
        ]) ...[
          (colors.onSurface, surface),
          (colors.onSurfaceVariant, surface),
          (colors.onPrimaryContainer, surface),
        ],
      ];
      for (final (foreground, background) in pairs) {
        expect(
          _contrast(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: '$foreground text on $background',
        );
      }
      expect(
        theme.textButtonTheme.style!.foregroundColor!.resolve({}),
        colors.onPrimaryContainer,
      );
      expect(
        theme.outlinedButtonTheme.style!.foregroundColor!.resolve({}),
        colors.onPrimaryContainer,
      );
    });

    testWidgets('${dark ? 'dark' : 'light'} attendance colors are unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              expect(
                context.attendancePresent,
                dark ? const Color(0xFF65D9A2) : const Color(0xFF018044),
              );
              expect(
                context.attendanceAbsent,
                dark ? const Color(0xFFFFB4AB) : const Color(0xFFBD262C),
              );
              expect(
                context.attendanceWarning,
                dark ? const Color(0xFFFFCE79) : const Color(0xFF925300),
              );
              for (final status in [
                context.attendancePresent,
                context.attendanceAbsent,
                context.attendanceWarning,
              ]) {
                for (final background in [
                  theme.scaffoldBackgroundColor,
                  colors.surface,
                  colors.surfaceContainerLow,
                ]) {
                  expect(
                    _contrast(status, background),
                    greaterThanOrEqualTo(4.5),
                  );
                }
              }
              return const Scaffold();
            },
          ),
        ),
      );
    });
  }
}

double _contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  return first > second
      ? (first + .05) / (second + .05)
      : (second + .05) / (first + .05);
}
