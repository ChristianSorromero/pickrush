import 'package:flutter/material.dart';

/// Single source of truth for colors.
/// NOTE: values were sampled by eye from the mockups. Replace with the
/// exact brand hex codes when available.
class AppColors {
  AppColors._();

  // Surfaces
  static const background = Color(0xFFF9F7F4);
  static const surface = Colors.white;
  static const border = Color(0xFFEAE6E1);

  // Brand
  static const primary = Color(0xFFFF6F61);
  static const primaryDark = Color(0xFFD63A1F); // links, active nav
  static const primarySoft = Color(0xFFFDECE9); // icon tile background

  // Text
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF55524E);
  static const textMuted = Color(0xFF9A958F);

  // Status
  static const success = Color(0xFF1DB954);
  static const successSoft = Color(0xFFE6F6EC);
  static const warning = Color(0xFFF08A1C);
  static const warningSoft = Color(0xFFFEF1E0);
  static const info = Color(0xFF3B82F6);
  static const infoSoft = Color(0xFFE8F0FE);
}
