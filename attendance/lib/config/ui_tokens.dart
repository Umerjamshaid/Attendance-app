import 'package:flutter/material.dart';

/// Shared dimensions; existing screen layouts keep their current values.
abstract final class AppLayout {
  static const gutter = 20.0;
  static const fieldRadius = 8.0;
  static const sheetRadius = 24.0;
  static const iconSize = 24.0;
  static const compactIconSize = 20.0;
  static const controlHeight = 52.0;
}

/// Bundled UI typography, with separate tabular-number styles retained in data UI.
abstract final class AppTypography {
  static const fontFamily = 'DM Sans';
  static const heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 1.2,
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
    height: 1.5,
    letterSpacing: 0,
  );
  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0,
  );
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: 0,
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
