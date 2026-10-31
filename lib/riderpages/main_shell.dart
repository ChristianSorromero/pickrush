import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/dashboard_models.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/account_screen.dart';
import 'package:rider_app/riderpages/login.dart';
import 'package:rider_app/riderpages/pickups/batch_routes.dart';
import 'package:rider_app/riderpages/pickups/pickups_screen.dart';
import 'package:rider_app/riderpages/earnings_screen.dart';
import 'package:rider_app/riderpages/rider_dashboard.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/auth_service.dart';
import 'package:rider_app/widgets/app_bottom_nav.dart';
import 'package:rider_app/widgets/icon_tile.dart';

/// Hosts the bottom navigation and keeps each tab alive. While it is open it
/// watches for new pickup batches and pops up a notice when one arrives.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _offerOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    assignmentWatcher
      ..onNewOffer = _announce
      ..onSignedOut = _signedOut
      ..addListener(_rebuild)
      ..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    assignmentWatcher
      ..removeListener(_rebuild)
      ..onNewOffer = null
      ..onSignedOut = null
      ..stop();
    super.dispose();
  }

  // Poll only while the rider is looking at the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      assignmentWatcher.start();
    } else if (state == AppLifecycleState.paused) {
      assignmentWatcher.stop();
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _announce(int batchId, RiderNotification? n) async {
    if (!mounted || _offerOpen) return;
    _offerOpen = true;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    final view = await showDialog<bool>(
      context: context,
      builder: (context) => _NewOfferDialog(notification: n),
    );
    _offerOpen = false;
    if (view == true && mounted) await openBatchById(context, batchId);
  }

  Future<void> _signedOut() async {
    await authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = assignmentWatcher;
    final items = [
      AppNavItem(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, showBadge: assignmentWatcher.unreadNotifications > 0),
      AppNavItem(label: 'Pickups', icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2_rounded, showBadge: w.hasPickupOffer),
      AppNavItem(label: 'Deliveries', icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping_rounded, showBadge: w.hasDeliveryOffer),
      const AppNavItem(label: 'Earnings', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded),
      const AppNavItem(label: 'Account', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(onSeeAllPickups: () => setState(() => _index = 1)),
          const PickupsScreen(),
          const PickupsScreen(type: BatchType.delivery),
          const EarningsScreen(),
          const AccountScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        items: items,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _NewOfferDialog extends StatelessWidget {
  const _NewOfferDialog({this.notification});
  final RiderNotification? notification;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconTile(icon: Icons.inventory_2_rounded, size: 56),
            AppSpacing.gapLg,
            Text(notification?.title ?? 'New assignment',
                textAlign: TextAlign.center, style: AppTextStyles.h2.copyWith(fontSize: 18)),
            AppSpacing.gapSm,
            Text(
              notification?.body ?? 'Your station sent you a new batch. Review it before accepting.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            AppSpacing.gapXl,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
                ),
                child: const Text('View assignment'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: const Text('Later'),
            ),
          ],
        ),
      ),
    );
  }
}
