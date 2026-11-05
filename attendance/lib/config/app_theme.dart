import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';

class AppTheme {
  static const Color primaryNavy = Color(0xFF1A1F71);
  static const Color accentGreen = Color(0xFF00D9A3);
  static const Color darkNavy = Color(0xFF0F1351);
  static const Color softGray = Color(0xFFF5F6FA);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);

  static final theme = _build(Brightness.light);
  static final darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      seedColor: primaryNavy,
      brightness: brightness,
      primary: dark ? const Color(0xFFB7BCFF) : primaryNavy,
      onPrimary: dark ? darkNavy : Colors.white,
      secondary: accentGreen,
      surface: dark ? const Color(0xFF141416) : Colors.white,
      onSurface: dark ? const Color(0xFFF1F0F2) : textPrimary,
      onSurfaceVariant: dark ? const Color(0xFFBDBBC2) : textSecondary,
      surfaceContainerLow: dark ? const Color(0xFF202023) : softGray,
      surfaceContainer: dark
          ? const Color(0xFF27272B)
          : const Color(0xFFF0F0F4),
      surfaceContainerHighest: dark
          ? const Color(0xFF343438)
          : const Color(0xFFEAEAF1),
      outlineVariant: dark ? const Color(0xFF3B3B42) : const Color(0xFFE4E5EB),
    );
    return ThemeData(
      colorScheme: colors,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: colors.surface,
      iconTheme: IconThemeData(size: 24, color: colors.onSurfaceVariant),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: 24,
          foregroundColor: colors.onSurfaceVariant,
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: colors.onSurfaceVariant),
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
        backgroundColor: colors.surface,
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
