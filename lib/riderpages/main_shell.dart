import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/main.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/models/dashboard_models.dart';
import 'package:rider_app/riderpages/account_screen.dart';
import 'package:rider_app/riderpages/earnings_screen.dart';
import 'package:rider_app/riderpages/login.dart';
import 'package:rider_app/riderpages/pickups/batch_routes.dart';
import 'package:rider_app/riderpages/rider_dashboard.dart';
import 'package:rider_app/riderpages/tasks_screen.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/auth_service.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/active_task_bar.dart';
import 'package:rider_app/widgets/app_bottom_nav.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/app_feedback.dart';
import 'package:rider_app/widgets/icon_tile.dart';

/// Hosts the four tabs (Today · Tasks · Wallet · Account) and keeps each
/// alive. Above the tabs: the batch in progress, one tap away, and a notice
/// while the app can't reach the server. While open it watches for new
/// batches and pops up a notice when one arrives.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver, RouteAware {
  int _index = 0;
  TaskSegment _segment = TaskSegment.offers;
  bool _offerOpen = false;

  /// The logistics company the rider works for, for the top bar.
  String? _company;

  /// Accepted batches, for the active-task bar.
  List<RiderBatch> _active = const [];
  int _seenChanges = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    assignmentWatcher
      ..onNewOffer = _announce
      ..onSignedOut = _signedOut
      ..addListener(_onWatcher)
      ..start();
    _loadActive();
    _loadCompany();
  }

  Future<void> _loadCompany() async {
    try {
      final account = await authService.me();
      if (mounted) setState(() => _company = account.company?.name);
    } on AuthException {
      // Offline: try again when the station next sends something.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    assignmentWatcher
      ..removeListener(_onWatcher)
      ..onNewOffer = null
      ..onSignedOut = null
      ..stop();
    super.dispose();
  }

  // Poll fast while the rider is looking at the app, slowly in the background
  // (each poll keeps them online; a closed app stops them and the server sets
  // the rider offline).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      assignmentWatcher.start();
    } else if (state == AppLifecycleState.paused) {
      assignmentWatcher.background();
    }
  }

  /// Back from a batch, a scan or any other page: progress may have moved.
  @override
  void didPopNext() => _loadActive();

  void _onWatcher() {
    if (assignmentWatcher.changes != _seenChanges) {
      _loadActive();
      if (_company == null) _loadCompany();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadActive() async {
    _seenChanges = assignmentWatcher.changes;
    try {
      final batches = await riderTasks.batches();
      if (!mounted) return;
      setState(() => _active = batches.where((b) => b.status == BatchStatus.accepted).toList());
    } on TaskException {
      // Keep what we had; the offline banner tells the rider.
    }
  }

  Future<void> _openActive() async {
    final b = _active.firstOrNull;
    if (b == null) return;
    if (_active.length > 1) {
      // Several in progress: show them all.
      setState(() {
        _index = 1;
        _segment = b.isDelivery ? TaskSegment.deliveries : TaskSegment.pickups;
      });
      return;
    }
    await openBatch(context, b);
  }

  /// "+N more" on Today: the Tasks tab on the most useful segment.
  void _showTasks() {
    setState(() {
      _index = 1;
      _segment = assignmentWatcher.offeredBatchIds.isNotEmpty
          ? TaskSegment.offers
          : (_active.firstOrNull?.isDelivery ?? false)
              ? TaskSegment.deliveries
              : TaskSegment.pickups;
    });
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
      const AppNavItem(label: 'Today', icon: Icons.today_outlined, activeIcon: Icons.today_rounded),
      AppNavItem(
          label: 'Tasks',
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          showBadge: w.offeredBatchIds.isNotEmpty),
      const AppNavItem(
          label: 'Wallet',
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded),
      const AppNavItem(label: 'Account', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
    ];

    return Scaffold(
      body: Column(
        children: [
          // Fixed above every tab: who the rider works for, then the offline notice.
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _CompanyBar(name: _company),
                OfflineBanner(visible: w.unreachable, lastSyncAt: w.lastSyncAt),
              ],
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: IndexedStack(
                index: _index,
                children: [
                  DashboardScreen(onSeeAllPickups: _showTasks),
                  TasksScreen(segment: _segment, onSegment: (s) => setState(() => _segment = s)),
                  const EarningsScreen(),
                  const AccountScreen(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ActiveTaskBar(
            batch: _active.firstOrNull,
            moreCount: _active.length - 1,
            onOpen: _openActive,
          ),
          AppBottomNav(
            items: items,
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
          ),
        ],
      ),
    );
  }
}

/// The strip at the top of the app: the logistics company the rider is hired
/// by (Pickrush, Mobloop...). Stays put while the tabs scroll under it.
class _CompanyBar extends StatelessWidget {
  const _CompanyBar({required this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.duration(context, AppMotion.small),
      curve: AppMotion.change,
      alignment: Alignment.topCenter,
      child: name == null
          ? const SizedBox(width: double.infinity)
          : Semantics(
              header: true,
              label: 'Hired by $name',
              excludeSemantics: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.sm),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business_rounded, size: 20, color: AppColors.primaryDark),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        name!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h2.copyWith(fontSize: 18, color: AppColors.primaryDark, letterSpacing: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
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
            AppButton(label: 'View assignment', onPressed: () => Navigator.pop(context, true)),
            AppSpacing.gapSm,
            AppButton(
              label: 'Later',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}
