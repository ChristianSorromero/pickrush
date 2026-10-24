import 'package:flutter/material.dart';
import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_theme.dart';
import 'package:rider_app/riderpages/application_status.dart';
import 'package:rider_app/riderpages/login.dart';
import 'package:rider_app/riderpages/main_shell.dart';
import 'package:rider_app/services/auth_service.dart';

void main() => runApp(const RiderApp());

class RiderApp extends StatelessWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pickrush Rider',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const StartupScreen(),
    );
  }
}

/// Opens where the rider left off: a remembered sign-in goes to the dashboard
/// (active) or their application status; otherwise the login screen.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    Widget next = const LoginScreen();
    if (await authService.restore()) {
      try {
        final account = await authService.me();
        next = account.status == RiderStatus.active
            ? const MainShell()
            : ApplicationStatusScreen(account: account);
      } on AuthException catch (e) {
        // Offline: the status screen retries; a dead token goes to login.
        if (!e.signedOut) next = const ApplicationStatusScreen();
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
