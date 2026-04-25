import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryNavy = Color(0xFF1A1F71);
  static const Color accentGreen = Color(0xFF00D9A3);
  static const Color darkNavy = Color(0xFF0F1351);
  static const Color softGray = Color(0xFFF5F6FA);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);

  static ThemeData get theme => ThemeData(
    primaryColor: primaryNavy,
    scaffoldBackgroundColor: Colors.white,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryNavy,
      primary: primaryNavy,
      secondary: accentGreen,
    ),
  );
}
