import 'package:attendance/config/app_theme.dart';
import 'package:attendance/config/utility_surface_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    final theme = dark ? AppTheme.darkTheme : AppTheme.theme;
    final colors = theme.colorScheme;

    test('${dark ? 'dark' : 'light'} uses the olive and gold palette', () {
      expect(
        colors.primary,
        dark ? const Color(0xFFD6E886) : const Color(0xFF4B571F),
      );
      expect(
        colors.primaryContainer,
        dark ? const Color(0xFF3C4926) : const Color(0xFFE2E9C9),
      );
      expect(
        theme.scaffoldBackgroundColor,
        dark ? const Color(0xFF292D29) : const Color(0xFFF8F8F5),
      );
      expect(colors.surface, theme.scaffoldBackgroundColor);
      expect(theme.appBarTheme.backgroundColor, theme.scaffoldBackgroundColor);
      expect(theme.textTheme.bodyLarge?.fontFamily, 'Inter');
    });

    test(
      '${dark ? 'dark' : 'light'} utility surfaces keep the warmer groups',
      () {
        final utility = utilitySurfaceThemeData(theme);
        expect(identical(utilitySurfaceThemeData(utility), utility), isTrue);
        expect(utility.scaffoldBackgroundColor, colors.surface);
        expect(
          utility.colorScheme.surfaceContainerHighest,
          colors.surfaceContainerHighest,
        );
        expect(
          utility.bottomSheetTheme.backgroundColor,
          colors.surfaceContainerHighest,
        );
        expect(
          (utility.inputDecorationTheme.focusedBorder as OutlineInputBorder)
              .borderRadius,
          BorderRadius.circular(22),
        );
      },
    );

    test('${dark ? 'dark' : 'light'} text pairs retain AA contrast', () {
      final pairs = [
        (colors.onPrimary, colors.primary),
        (colors.onPrimaryContainer, colors.primaryContainer),
        (colors.onSecondary, colors.secondary),
        (colors.onSecondaryContainer, colors.secondaryContainer),
        (colors.onTertiary, colors.tertiary),
        (colors.onTertiaryContainer, colors.tertiaryContainer),
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
        colors.onSurface,
      );
      expect(
        theme.outlinedButtonTheme.style!.foregroundColor!.resolve({}),
        colors.onSurface,
      );
    });

    testWidgets(
      '${dark ? 'dark' : 'light'} attendance status colors remain accessible',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                expect(
                  context.attendancePresent,
                  dark ? const Color(0xFF3DD68C) : const Color(0xFF1C7A50),
                );
                expect(context.attendanceAbsent, colors.error);
                expect(
                  context.attendanceWarning,
                  dark ? const Color(0xFFF2D779) : const Color(0xFF805B0E),
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
                    colors.surfaceContainerHighest,
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
      },
    );
  }
}

double _contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  return first > second
      ? (first + .05) / (second + .05)
      : (second + .05) / (first + .05);
}
