import 'package:attendance/config/app_theme.dart';
import 'package:attendance/config/utility_surface_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    final theme = dark ? AppTheme.darkTheme : AppTheme.theme;
    final colors = theme.colorScheme;

    test(
      '${dark ? 'dark' : 'light'} uses soft gray surfaces and teal accents',
      () {
        expect(
          colors.primary,
          dark ? const Color(0xFF67D5E5) : const Color(0xFF167D8D),
        );
        expect(
          colors.primaryContainer,
          dark ? const Color(0xFF30484D) : const Color(0xFFDFF1F3),
        );
        expect(
          theme.scaffoldBackgroundColor,
          dark ? const Color(0xFF242629) : const Color(0xFFF7F9FA),
        );
        expect(colors.surface, dark ? const Color(0xFF242629) : Colors.white);
        expect(
          theme.appBarTheme.backgroundColor,
          theme.scaffoldBackgroundColor,
        );
        expect(theme.textTheme.bodyLarge?.fontFamily, 'Inter');
      },
    );

    test('${dark ? 'dark' : 'light'} utility surfaces do not swap twice', () {
      final utility = utilitySurfaceThemeData(theme);
      expect(identical(utilitySurfaceThemeData(utility), utility), isTrue);
      expect(utility.scaffoldBackgroundColor, colors.surfaceContainerHighest);
      expect(utility.colorScheme.surfaceContainerHighest, colors.surface);
      expect(
        (utility.inputDecorationTheme.focusedBorder as OutlineInputBorder)
            .borderRadius,
        BorderRadius.circular(22),
      );
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
                  dark ? const Color(0xFFFFCA16) : const Color(0xFF925300),
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
