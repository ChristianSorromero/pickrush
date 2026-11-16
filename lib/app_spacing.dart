import 'package:flutter/material.dart';

/// Spacing follows the Picksell scale (4 · 8 · 12 · 16 · 24 · 32) with the
/// same 16pt page gutter as the Buyer app.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal padding used by every screen.
  static const double screenH = 16;

  static const gapXs = SizedBox(height: xs, width: xs);
  static const gapSm = SizedBox(height: sm, width: sm);
  static const gapMd = SizedBox(height: md, width: md);
  static const gapLg = SizedBox(height: lg, width: lg);
  static const gapXl = SizedBox(height: xl, width: xl);
  static const gapXxl = SizedBox(height: xxl, width: xxl);
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;

  /// Cards: a little tighter than the Buyer's 20 so the Rider app reads as a tool.
  static const double lg = 16;
  static const double pill = 999;

  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get pillAll => BorderRadius.circular(pill);

  /// Buttons and fields (same as Buyer).
  static BorderRadius get button => BorderRadius.circular(14);
  static const BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(28));
}

class AppSize {
  AppSize._();

  /// Minimum interactive target.
  static const double minTap = 44;
  static const double buttonHeight = 52;
}

/// Motion timings from the Buyer app (`PsMotion`). Critical rider actions
/// (scan, confirm, arrive) never wait on these: feedback starts at once and
/// the server call is not delayed. Everything goes through [duration] so the
/// phone's "remove animations" setting turns it off.
class AppMotion {
  AppMotion._();

  static const Duration press = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration icon = Duration(milliseconds: 200);
  static const Duration small = Duration(milliseconds: 220);
  static const Duration content = Duration(milliseconds: 280);
  static const Duration page = Duration(milliseconds: 300);
  static const Duration pageBack = Duration(milliseconds: 250);
  static const Duration sheet = Duration(milliseconds: 300);
  static const Duration sheetBack = Duration(milliseconds: 220);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve change = Curves.easeInOutCubic;

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or zero under reduced motion.
  static Duration duration(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}
