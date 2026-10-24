import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/dashboard_models.dart';
import 'package:rider_app/riderpages/pickups/batch_routes.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/icon_tile.dart';

/// What the station sent: new pickup batches, pickups taken back...
/// Opening the list marks everything read.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<RiderNotification>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await riderTasks.notifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
      if (items.any((n) => !n.isRead)) {
        assignmentWatcher.markAllRead();
        await riderTasks.markNotificationsRead();
      }
    } on TaskException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('Notifications', style: AppTextStyles.h2.copyWith(fontSize: 18)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: items == null
            ? ListView(children: [
                Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: Center(
                    child: _error == null
                        ? const CircularProgressIndicator(color: AppColors.primary)
                        : Text(_error!, style: AppTextStyles.body),
                  ),
                ),
              ])
            : items.isEmpty
                ? ListView(children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 120),
                      child: Center(
                          child: Text('No notifications yet.',
                              style: AppTextStyles.body)),
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH, vertical: AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) => _Tile(
                      n: items[i],
                      onTap: items[i].batchId == null
                          ? null
                          : () => openBatchById(context, items[i].batchId!),
                    ),
                  ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.n, this.onTap});
  final RiderNotification n;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final newPickup = n.isOffer;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(
              icon: newPickup ? Icons.inventory_2_rounded : Icons.info_outline_rounded,
              color: newPickup ? AppColors.primaryDark : AppColors.warning,
              background: newPickup ? AppColors.primarySoft : AppColors.warningSoft,
              size: 36,
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title,
                      style: AppTextStyles.bodyStrong.copyWith(
                          fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800)),
                  if (n.body != null) ...[
                    const SizedBox(height: 2),
                    Text(n.body!, style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 4),
                  Text(timeAgo(n.createdAt), style: AppTextStyles.caption),
                ],
              ),
            ),
            if (!n.isRead)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 8),
                height: 8,
                width: 8,
                decoration: const BoxDecoration(
                    color: AppColors.primaryDark, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
