import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:rider_app/app_colors.dart';

/// Typography: Open Sans for screen titles (shared with Picksell Buyer),
/// Manrope for everything else — the Rider app's own voice. Numbers a rider
/// reads at a glance (waybills, pesos, counts) use tabular figures.
class AppTextStyles {
  AppTextStyles._();

  static const _tabular = [FontFeature.tabularFigures()];

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

  static TextStyle _title(double size, {FontWeight weight = FontWeight.w800}) => GoogleFonts.openSans(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -0.3,
        height: 1.2,
        color: AppColors.textPrimary,
      );

  /// Big hero numbers (today's earnings, wallet balance).
  static TextStyle get display =>
      _base(size: 34, weight: FontWeight.w800, letterSpacing: -0.8).copyWith(fontFeatures: _tabular);

  /// Screen titles ("Tasks", "Wallet").
  static TextStyle get h1 => _title(24);

  /// Card and section headings.
  static TextStyle get h2 => _base(size: 16, weight: FontWeight.w800, letterSpacing: -0.2);

  static TextStyle get body => _base(size: 14, color: AppColors.textSecondary, height: 1.45);
  static TextStyle get bodyStrong => _base(size: 14, weight: FontWeight.w600);
  static TextStyle get label => _base(size: 13, weight: FontWeight.w700);
  static TextStyle get button => _base(size: 15, weight: FontWeight.w800, letterSpacing: 0.1);
  static TextStyle get link => _base(size: 14, weight: FontWeight.w700, color: AppColors.primaryDark);
  static TextStyle get overline =>
      _base(size: 12, weight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.6);
  static TextStyle get caption => _base(size: 12, color: AppColors.textMuted, height: 1.4);
  static TextStyle get navLabel => _base(size: 11.5, weight: FontWeight.w700, color: AppColors.textMuted);

  /// Waybills, batch numbers, peso amounts, counts.
  static TextStyle get numeric =>
      _base(size: 15, weight: FontWeight.w800, letterSpacing: -0.2).copyWith(fontFeatures: _tabular);
}
