import 'package:flutter/material.dart';

/// Shared dimensions; existing screen layouts keep their current values.
abstract final class AppLayout {
  static const gutter = 20.0;
  static const fieldRadius = 8.0;
  static const sheetRadius = 24.0;
  static const iconSize = 24.0;
  static const compactIconSize = 20.0;
  static const controlHeight = 52.0;
  static const groupRadius = 22.0;
}

/// Bundled UI typography, with separate tabular-number styles retained in data UI.
abstract final class AppTypography {
  static const fontFamily = 'Inter';
  static const heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0,
  );
  static const title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
  );
  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.25,
    letterSpacing: 0,
  );
  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.25,
    letterSpacing: 0,
  );
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.25,
    letterSpacing: 0,
  );

  /// Offline Inter styles for existing data widgets and explicit numeric features.
  static TextStyle inter({
    TextStyle? textStyle,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    Color? color,
    List<FontFeature>? fontFeatures,
    double? letterSpacing,
  }) => (textStyle ?? const TextStyle()).copyWith(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    color: color,
    fontFeatures: fontFeatures,
    letterSpacing: letterSpacing ?? 0,
  );

  // Type scale adapted from Block Buzz's shared/theme/text_theme.dart (Apache-2.0).
  static const textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 52,
      height: 1.23,
      letterSpacing: 0,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 44,
      height: 1.18,
      letterSpacing: 0,
    ),
    displaySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 36,
      height: 1.22,
      letterSpacing: 0,
    ),
    headlineLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 32,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: 0,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 1.29,
      letterSpacing: 0,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.33,
      letterSpacing: 0,
    ),
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w400,
      height: 1.25,
      letterSpacing: 0,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w500,
      height: 1.3,
      letterSpacing: 0,
    ),
    titleSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 22 / 16,
      letterSpacing: 0,
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.2,
      letterSpacing: 0,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.25,
      letterSpacing: 0,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.2,
      letterSpacing: 0,
    ),
    bodyLarge: body,
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      height: 1.3,
      letterSpacing: 0,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      height: 1.25,
      letterSpacing: 0,
    ),
  );

  static ThemeData themeOf(BuildContext context, {String family = fontFamily}) {
    final theme = Theme.of(context);
    return theme.copyWith(
      textTheme: theme.textTheme.apply(
        fontFamily: family,
        letterSpacingFactor: 0,
      ),
      primaryTextTheme: theme.primaryTextTheme.apply(
        fontFamily: family,
        letterSpacingFactor: 0,
      ),
    );
  }
}

/// Local motion stays separate from Provider's application state.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 220);
  static const entrance = Duration(milliseconds: 320);
  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;
  static const pageSpring = SpringDescription(
    mass: .5,
    stiffness: 200,
    damping: 18,
  );
  static const pressSpring = SpringDescription(
    mass: .5,
    stiffness: 500,
    damping: 32,
  );

  static Duration duration(BuildContext context, Duration value) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
}
