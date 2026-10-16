import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:rider_app/app_colors.dart';

/// Typography. The font looks like Manrope in the mockups.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _base({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.textPrimary,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle get display => _base(size: 34, weight: FontWeight.w800);
  static TextStyle get h1 => _base(size: 28, weight: FontWeight.w700);
  static TextStyle get h2 => _base(size: 16, weight: FontWeight.w700);
  static TextStyle get body =>
      _base(size: 14, color: AppColors.textSecondary, height: 1.4);
  static TextStyle get bodyStrong => _base(size: 13, weight: FontWeight.w600);
  static TextStyle get label => _base(size: 13, weight: FontWeight.w600);
  static TextStyle get button => _base(size: 15, weight: FontWeight.w700);
  static TextStyle get link => _base(
      size: 13, weight: FontWeight.w600, color: AppColors.primaryDark);
  static TextStyle get overline => _base(
      size: 12,
      weight: FontWeight.w600,
      color: AppColors.textSecondary,
      letterSpacing: 0.4);
  static TextStyle get caption => _base(size: 11, color: AppColors.textMuted);
  static TextStyle get navLabel =>
      _base(size: 10, weight: FontWeight.w600, color: AppColors.textMuted);
}
