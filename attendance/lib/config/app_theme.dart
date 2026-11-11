import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';
import 'ui_tokens.dart';

class AppTheme {
  static const Color primaryPetrol = Color(0xFF167D8D);
  static const Color darkPetrol = Color(0xFF102B31);
  // Keep the existing color names compatible for downstream callers.
  static const Color primaryNavy = primaryPetrol;
  static const Color darkNavy = darkPetrol;
  static const Color accentGreen = Color(0xFF00D9A3);
  static const Color softGray = Color(0xFFF0F3F5);
  static const Color textPrimary = Color(0xFF202326);
  static const Color textSecondary = Color(0xFF5D6368);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);

  static final theme = _build(Brightness.light);
  static final darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xFF141719) : const Color(0xFFF7F9FA);
    final colors = ColorScheme.fromSeed(
      seedColor: primaryPetrol,
      brightness: brightness,
      primary: dark ? const Color(0xFF67D5E5) : primaryPetrol,
      onPrimary: dark ? darkPetrol : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF16343A)
          : const Color(0xFFDFF1F3),
      onPrimaryContainer: dark
          ? const Color(0xFFA7E5ED)
          : const Color(0xFF125661),
      secondary: dark ? const Color(0xFFBBCBD1) : const Color(0xFF52666E),
      onSecondary: dark ? const Color(0xFF25353C) : Colors.white,
      secondaryContainer: dark
          ? const Color(0xFF2D3A40)
          : const Color(0xFFE4EBEE),
      onSecondaryContainer: dark
          ? const Color(0xFFDDE7EB)
          : const Color(0xFF33464F),
      surface: dark ? const Color(0xFF1F2327) : Colors.white,
      onSurface: dark ? const Color(0xFFF1F3F5) : textPrimary,
      onSurfaceVariant: dark ? const Color(0xFFADB5BD) : textSecondary,
      surfaceDim: dark ? background : const Color(0xFFDCE1E4),
      surfaceBright: dark ? const Color(0xFF3B4147) : background,
      surfaceContainerLowest: dark ? background : Colors.white,
      surfaceContainerLow: dark ? const Color(0xFF272D32) : softGray,
      surfaceContainer: dark
          ? const Color(0xFF2D343A)
          : const Color(0xFFE8EDF0),
      surfaceContainerHigh: dark
          ? const Color(0xFF333B42)
          : const Color(0xFFE2E8EC),
      surfaceContainerHighest: dark
          ? const Color(0xFF394148)
          : const Color(0xFFDCE3E8),
      outline: dark ? const Color(0xFF89949C) : const Color(0xFF727D85),
      outlineVariant: dark ? const Color(0xFF424A51) : const Color(0xFFD7DEE2),
      inverseSurface: dark ? const Color(0xFFE4E9EC) : const Color(0xFF2D3237),
      onInverseSurface: dark ? textPrimary : const Color(0xFFF1F3F5),
      inversePrimary: dark ? const Color(0xFF125661) : const Color(0xFF67D5E5),
    );
    return ThemeData(
      colorScheme: colors,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: background,
      iconTheme: IconThemeData(size: 24, color: colors.onSurfaceVariant),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: 24,
          foregroundColor: colors.onSurfaceVariant,
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: colors.onSurfaceVariant),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: AppTypography.label.copyWith(
          color: colors.onSurfaceVariant,
        ),
        hintStyle: AppTypography.body.copyWith(color: colors.onSurfaceVariant),
        errorStyle: AppTypography.caption.copyWith(color: colors.error),
        prefixIconColor: colors.onSurfaceVariant,
        suffixIconColor: colors.onSurfaceVariant,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 52,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.fieldRadius),
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.fieldRadius),
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.fieldRadius),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.fieldRadius),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.fieldRadius),
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.onPrimaryContainer),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onPrimaryContainer,
        ),
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) =>
            const Icon(AppIcons.chevronLeft, size: 24),
        closeButtonIconBuilder: (_) => const Icon(AppIcons.x, size: 24),
        drawerButtonIconBuilder: (_) =>
            const Icon(AppIcons.adjustments, size: 24),
        endDrawerButtonIconBuilder: (_) =>
            const Icon(AppIcons.adjustments, size: 24),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        iconTheme: IconThemeData(size: 24, color: colors.onSurfaceVariant),
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant),
      dialogTheme: DialogThemeData(backgroundColor: colors.surfaceContainerLow),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: colors.surface),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
    );
  }
}

extension AttendanceThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get _dark => colors.brightness == Brightness.dark;
  Color get attendancePresent =>
      _dark ? const Color(0xFF65D9A2) : const Color(0xFF018044);
  Color get attendanceAbsent =>
      _dark ? const Color(0xFFFFB4AB) : const Color(0xFFBD262C);
  Color get attendanceWarning =>
      _dark ? const Color(0xFFFFCE79) : const Color(0xFF925300);
}

// ─────────────────────────── THEME ───────────────────────────
class AppColors {
  static const bg = Color(0xFFF5F5F5);
  static const dark = Color(0xFF0F0F0F);
  static const card = Color(0xFFFFFFFF);
  static const present = Color(0xFF00C853);
  static const absent = Color(0xFFFF3B30);
  static const muted = Color(0xFF9E9E9E);
  static const surface = Color(0xFF1C1C1C);
  static const divider = Color(0xFFEEEEEE);
}
