import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';
import 'buzz_color_scheme.dart';
import 'ui_tokens.dart';

enum AppPalette {
  olive('Olive & Gold'),
  tide('Tide', Color(0xFF006D73)),
  iris('Iris', Color(0xFF7155A2)),
  graphite('Graphite', Color(0xFF53605F));

  const AppPalette(this.label, [this.seed]);

  final String label;
  final Color? seed;
}

class AppTheme {
  static const Color primaryPetrol = Color(0xFF4B571F);
  static const Color darkPetrol = Color(0xFF292D29);
  // Keep the existing color names compatible for downstream callers.
  static const Color primaryNavy = primaryPetrol;
  static const Color darkNavy = darkPetrol;
  static const Color accentGreen = Color(0xFF00D9A3);
  static const Color softGray = Color(0xFFF0F3F5);
  static const Color textPrimary = Color(0xFF202326);
  static const Color textSecondary = Color(0xFF5D6368);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);

  static final theme = _build(buzzLightScheme);
  static final darkTheme = _build(buzzDarkScheme);
  static final _themes = {
    for (final palette in AppPalette.values)
      if (palette.seed != null)
        for (final brightness in Brightness.values)
          (palette, brightness): _build(_scheme(palette, brightness)),
  };

  static ThemeData forPalette(AppPalette palette, Brightness brightness) =>
      _themes[(palette, brightness)] ??
      (brightness == Brightness.dark ? darkTheme : theme);

  static ColorScheme _scheme(AppPalette palette, Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: palette.seed!,
      brightness: brightness,
      dynamicSchemeVariant: palette == AppPalette.graphite
          ? DynamicSchemeVariant.neutral
          : DynamicSchemeVariant.tonalSpot,
      surfaceTint: Colors.transparent,
    );
    if (brightness == Brightness.light) {
      return colors.copyWith(
        surfaceContainerHighest: Color.alphaBlend(
          const Color(0x80FFFFFF),
          colors.surfaceContainerHighest,
        ),
      );
    }

    // Keep the dark surfaces closer to charcoal than black.
    Color lift(Color tone) => Color.alphaBlend(const Color(0x15FFFFFF), tone);
    return colors.copyWith(
      surface: lift(colors.surface),
      surfaceDim: lift(colors.surfaceDim),
      surfaceBright: lift(colors.surfaceBright),
      surfaceContainerLowest: lift(colors.surfaceContainerLowest),
      surfaceContainerLow: lift(colors.surfaceContainerLow),
      surfaceContainer: lift(colors.surfaceContainer),
      surfaceContainerHigh: lift(colors.surfaceContainerHigh),
      surfaceContainerHighest: lift(colors.surfaceContainerHighest),
    );
  }

  static ThemeData _build(ColorScheme colors) {
    final dark = colors.brightness == Brightness.dark;
    final background = colors.surface;
    final control = dark
        ? colors.surfaceContainerHigh
        : colors.primaryContainer;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    final inputLabel = WidgetStateTextStyle.resolveWith(
      (states) => AppTypography.label.copyWith(
        color: states.contains(WidgetState.error)
            ? colors.error
            : colors.onSurfaceVariant,
      ),
    );
    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme,
      splashFactory: NoSplash.splashFactory,
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
        labelStyle: inputLabel,
        floatingLabelStyle: inputLabel,
        hintStyle: AppTypography.body.copyWith(color: colors.onSurfaceVariant),
        errorStyle: AppTypography.caption.copyWith(color: colors.error),
        errorMaxLines: 8,
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
        style: TextButton.styleFrom(
          foregroundColor: colors.onSurface,
          minimumSize: const Size(44, 44),
          shape: buttonShape,
          textStyle: AppTypography.label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          backgroundColor: control,
          side: BorderSide(color: colors.outline),
          minimumSize: const Size(44, 44),
          shape: buttonShape,
          textStyle: AppTypography.label,
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.surfaceContainerHigh,
          disabledForegroundColor: colors.onSurfaceVariant,
          minimumSize: const Size(44, 44),
          shape: buttonShape,
          textStyle: AppTypography.label,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: control,
          foregroundColor: colors.onSurface,
          elevation: 0,
          minimumSize: const Size(44, 44),
          shape: buttonShape,
          textStyle: AppTypography.label,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        iconTheme: IconThemeData(size: 24, color: colors.onSurfaceVariant),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.textTheme.titleMedium?.copyWith(
          color: colors.onSurface,
        ),
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.outline),
        ),
        titleTextStyle: AppTypography.title.copyWith(
          fontSize: 18,
          color: colors.onSurface,
        ),
        contentTextStyle: AppTypography.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerHighest,
        modalBackgroundColor: colors.surfaceContainerHighest,
        elevation: 0,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerHighest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: buttonShape,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        strokeWidth: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: AppTypography.textTheme.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        actionTextColor: colors.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

extension AttendanceThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get _dark => colors.brightness == Brightness.dark;
  Color get attendancePresent =>
      _dark ? const Color(0xFF3DD68C) : const Color(0xFF1C7A50);
  Color get attendanceAbsent => colors.error;
  Color get attendanceWarning =>
      _dark ? const Color(0xFFF2D779) : const Color(0xFF805B0E);
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
