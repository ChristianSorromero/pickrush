import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rider_app/app_assets.dart';
import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_theme.dart';
import 'package:rider_app/riderpages/application_status.dart';
import 'package:rider_app/riderpages/login.dart';
import 'package:rider_app/riderpages/main_shell.dart';
import 'package:rider_app/services/auth_service.dart';

void main() => runApp(const RiderApp());

/// Lets screens hear when a pushed page closes (e.g. the shell refreshes the
/// active-task bar after the rider works a batch).
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();

class RiderApp extends StatelessWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSL Logistics',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorObservers: [appRouteObserver],
      home: const StartupScreen(),
    );
  }
}

/// Animated launch screen (same feel as the PickSell buyer app, light):
/// an orange glow blooms, the PSL mark scales in, the PSL LOGISTICS
/// wordmark rises letter by letter and a thin progress line runs while the
/// saved sign-in is checked. Then it opens where the rider left off: the
/// dashboard (active), their application status, or the login screen.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> with SingleTickerProviderStateMixin {
  static const _brand = Color(0xFFE96C36);
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    _c.forward();
    _route();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _route() async {
    // Work out the destination while the animation plays; leave when both are done.
    final results = await Future.wait([_destination(), Future<void>.delayed(const Duration(milliseconds: 2300))]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => results[0] as Widget,
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  Future<Widget> _destination() async {
    if (!await authService.restore()) return const LoginScreen();
    try {
      final account = await authService.me();
      return account.status == RiderStatus.active ? const MainShell() : ApplicationStatusScreen(account: account);
    } on AuthException catch (e) {
      // Offline: the status screen retries; a dead token goes to login.
      return e.signedOut ? const LoginScreen() : const ApplicationStatusScreen();
    }
  }

  Animation<double> _interval(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _c, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final glow = _interval(0.0, 0.55);
    final mark = _interval(0.08, 0.5, Curves.easeOutBack);
    final progress = _interval(0.35, 1.0, Curves.easeInOut);
    const word = 'PSL LOGISTICS';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: [
              // Orange glow behind the mark.
              Center(
                child: Opacity(
                  opacity: glow.value * 0.8,
                  child: Transform.scale(
                    scale: 0.6 + glow.value * 0.6,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [_brand.withAlpha(60), _brand.withAlpha(0)]),
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: mark.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * mark.value,
                        child: Image.asset(AppAssets.logoMark, width: 140, height: 140),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < word.length; i++)
                          Builder(builder: (_) {
                            final t = _interval(0.3 + i * 0.03, 0.62 + i * 0.03).value;
                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, 14 * (1 - t)),
                                child: Text(
                                  word[i],
                                  style: GoogleFonts.montserrat(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                    color: i < 3 ? _brand : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: _interval(0.65, 0.95).value,
                      child: Text(
                        'Rider app · Delivery partner of PickSell',
                        style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textMuted, letterSpacing: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
              // Thin progress line near the bottom.
              Positioned(
                bottom: 64 + MediaQuery.paddingOf(context).bottom,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 120,
                    height: 3,
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    child: FractionallySizedBox(
                      widthFactor: math.max(0.02, progress.value),
                      child: Container(
                        decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
