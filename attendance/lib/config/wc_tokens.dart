import 'package:flutter/material.dart';

class WC {
  WC._();

  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF6F6F6);
  static const card = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF0F0F0);
  static const border = Color(0xFFE5E5E5);
  static const muted = Color(0xFF9B9B9B);
  static const present = Color(0xFF018A45);
  static const absent = Color(0xFFD63031);
  static const accentBlue = Color(0xFF276EF1);
  static const accentGreen = Color(0xFF2ECC71);
  static const accent = Color(0xFFF1C40F);

  static BorderRadius get r8 => BorderRadius.circular(8);
  static BorderRadius get r12 => BorderRadius.circular(12);
  static BorderRadius get r16 => BorderRadius.circular(16);
  static BorderRadius get r20 => BorderRadius.circular(20);
  static BorderRadius get rFull => BorderRadius.circular(100);

  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];
}
