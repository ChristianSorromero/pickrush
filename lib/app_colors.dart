import 'package:flutter/material.dart';

/// Single source of truth for colors. Matches the Picksell Buyer palette
/// (picksell-buyer `PsColors`, light set) so both apps read as one family;
/// what differs is how the Rider app *uses* it: coral means "act here",
/// and the status colors below carry the task state.
class AppColors {
  AppColors._();

  // Surfaces
  static const background = Color(0xFFF9F8F6);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF3F4F6);
  static const border = Color(0xFFE5E7EB);
  static const divider = Color(0xFFEFEFEF);
  static const scrim = Color(0x66000000);

  // Brand
  static const primary = Color(0xFFFF6F61);

  /// Deep coral: links, active nav, coral text on light surfaces.
  static const primaryDark = Color(0xFFBF3526);
  static const primarySoft = Color(0xFFFAEBE8);

  /// Text and icons on a coral fill. Near-black, never white (white on
  /// coral is ~2.6:1 and unreadable in sunlight).
  static const onPrimary = Color(0xFF1B1B1B);

  // Text
  static const textPrimary = Color(0xFF1B1B1B);
  static const textSecondary = Color(0xFF4B5563);
  static const textMuted = Color(0xFF6B7280);
  static const textDisabled = Color(0xFFC4C7CC);

  // Feedback
  static const success = Color(0xFF2E7D32);
  static const successSoft = Color(0xFFE8F5E9);
  static const warning = Color(0xFFB45309);
  static const warningSoft = Color(0xFFFEF3C7);
  static const error = Color(0xFFDC2626);
  static const errorStrong = Color(0xFFB91C1C);
  static const errorSoft = Color(0xFFFEF2F2);
  static const info = Color(0xFF1D4ED8);
  static const infoSoft = Color(0xFFEFF6FF);
}

/// What a task is doing, and the color that says so everywhere (rails,
/// chips, the active-task bar).
enum TaskTone {
  /// A new batch the station offered: review it.
  offer(AppColors.info, AppColors.infoSoft),

  /// Accepted and in progress: the rider's current work.
  active(AppColors.primaryDark, AppColors.primarySoft),

  /// Finished.
  done(AppColors.success, AppColors.successSoft),

  /// Needs a look (far from the pin, document expiring...).
  attention(AppColors.warning, AppColors.warningSoft),

  /// Failed, refused or blocked.
  failed(AppColors.errorStrong, AppColors.errorSoft),

  /// Cancelled or taken back.
  muted(AppColors.textSecondary, AppColors.surfaceMuted);

  const TaskTone(this.color, this.soft);

  final Color color;
  final Color soft;
}
