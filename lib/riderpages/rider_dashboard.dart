import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/dashboard_models.dart';
import 'package:rider_app/riderpages/notifications_screen.dart';
import 'package:rider_app/riderpages/pickups/batch_routes.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/activity_timeline.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/dashboard_top_bar.dart';
import 'package:rider_app/widgets/earnings_header.dart';
import 'package:rider_app/widgets/next_assignment_card.dart';
import 'package:rider_app/widgets/section_header.dart';
import 'package:rider_app/widgets/stats_row.dart';

/// Home: online status, today's numbers, the next batch and recent activity,
/// all from `/api/rider/dashboard`. Reloads when the station sends something.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onSeeAllPickups});

  /// Switches the shell to the Pickups tab.
  final VoidCallback? onSeeAllPickups;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;
  String? _error;
  bool _switching = false;
  int _seenChanges = -1;

  @override
  void initState() {
    super.initState();
    assignmentWatcher.addListener(_onWatcher);
    _load();
  }

  @override
  void dispose() {
    assignmentWatcher.removeListener(_onWatcher);
    super.dispose();
  }

  void _onWatcher() {
    if (assignmentWatcher.changes != _seenChanges) {
      _load();
    } else if (mounted) {
      setState(() {}); // badge only
    }
  }

  Future<void> _load() async {
    _seenChanges = assignmentWatcher.changes;
    try {
      final data = await riderTasks.dashboard();
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } on TaskException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggleOnline() async {
    final data = _data;
    if (data == null || _switching) return;
    final goOnline = !data.isOnline;
    if (!goOnline) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Go offline?'),
          content: const Text(
              'Your station will stop assigning you new pickups until you go online again.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay online')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Go offline')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _switching = true);
    try {
      await riderTasks.setOnline(goOnline);
      await _load();
    } on TaskException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    _load();
  }

  Future<void> _accept(int batchId) async {
    try {
      final batch = await riderTasks.accept(batchId);
      assignmentWatcher.poll();
      if (!mounted) return;
      await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => acceptedBatchScreen(batch)));
      _load();
    } on TaskException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
        _load();
      }
      rethrow; // resets the slider
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return SafeArea(
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator(color: AppColors.primary)
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          textAlign: TextAlign.center, style: AppTextStyles.body),
                      AppSpacing.gapLg,
                      AppButton(label: 'Try again', onPressed: _load, expand: false),
                    ],
                  ),
                ),
        ),
      );
    }

    final next = data.nextBatch;
    final others = data.batches.length - 1;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
          children: [
            DashboardTopBar(
              isOnline: data.isOnline,
              hubName: data.hub?.name ?? 'No station',
              hasNotifications: assignmentWatcher.unreadNotifications > 0,
              onToggleOnline: _toggleOnline,
              onNotifications: _openNotifications,
            ),
            AppSpacing.gapXl,
            EarningsHeader(amount: data.todayEarnings),
            AppSpacing.gapLg,
            StatsRow(pickups: data.pickups, delivered: data.delivered),
            AppSpacing.gapXxl,
            SectionHeader(
              title: 'Next Assignment',
              actionLabel: next == null ? null : 'View Details',
              onActionTap: next == null
                  ? null
                  : () => openBatch(context, next).then((_) => _load()),
            ),
            AppSpacing.gapMd,
            NextAssignmentCard(
              batch: next,
              isOnline: data.isOnline,
              onOpen: next == null
                  ? null
                  : () => openBatch(context, next).then((_) => _load()),
              onAccept: next == null ? null : () => _accept(next.id),
            ),
            if (others > 0) ...[
              AppSpacing.gapSm,
              Center(
                child: TextButton(
                  onPressed: widget.onSeeAllPickups,
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
                  child: Text('+$others more ${others == 1 ? 'batch' : 'batches'} in Pickups'),
                ),
              ),
            ],
            AppSpacing.gapXxl,
            const SectionHeader(title: 'Recent Activity'),
            AppSpacing.gapMd,
            ActivityTimeline(items: data.activity),
            AppSpacing.gapLg,
          ],
        ),
      ),
    );
  }
}
