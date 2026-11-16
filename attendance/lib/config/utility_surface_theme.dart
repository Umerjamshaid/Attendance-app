// Adapted from Block Buzz, Copyright 2026 Block, Inc., Apache-2.0.
// Utility pages use neutral page surfaces and distinct grouped controls.
import 'package:flutter/material.dart';
import 'ui_tokens.dart';

ThemeData utilitySurfaceThemeData(ThemeData theme) {
  if (theme.extension<_UtilitySurfaceMarker>() != null) return theme;
  final colors = theme.colorScheme;
  return theme.copyWith(
    scaffoldBackgroundColor: colors.surfaceContainerHighest,
    colorScheme: colors.copyWith(
      surface: colors.surfaceContainerHighest,
      surfaceContainerHighest: colors.surface,
    ),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      fillColor: colors.surface,
      border: _rounded(theme.inputDecorationTheme.border),
      enabledBorder: _rounded(theme.inputDecorationTheme.enabledBorder),
      focusedBorder: _rounded(theme.inputDecorationTheme.focusedBorder),
      errorBorder: _rounded(theme.inputDecorationTheme.errorBorder),
      focusedErrorBorder: _rounded(
        theme.inputDecorationTheme.focusedErrorBorder,
      ),
      disabledBorder: _rounded(theme.inputDecorationTheme.disabledBorder),
    ),
    bottomSheetTheme: theme.bottomSheetTheme.copyWith(
      backgroundColor: colors.surfaceContainerHighest,
      modalBackgroundColor: colors.surfaceContainerHighest,
    ),
    extensions: [...theme.extensions.values, const _UtilitySurfaceMarker()],
  );
}

InputBorder? _rounded(InputBorder? border) => border is OutlineInputBorder
    ? border.copyWith(
        borderRadius: BorderRadius.circular(AppLayout.groupRadius),
      )
    : border;

class _UtilitySurfaceMarker extends ThemeExtension<_UtilitySurfaceMarker> {
  const _UtilitySurfaceMarker();
  @override
  _UtilitySurfaceMarker copyWith() => this;
  @override
  _UtilitySurfaceMarker lerp(
    covariant _UtilitySurfaceMarker? other,
    double t,
  ) => this;
}
