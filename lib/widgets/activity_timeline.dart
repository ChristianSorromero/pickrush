import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/dashboard_models.dart';

class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({super.key, required this.items, this.clockTime = false});

  final List<ActivityItem> items;

  /// Show the time of day ("10:42 AM") instead of "5 mins ago", for lists
  /// grouped under a day header.
  final bool clockTime;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text('No activity yet today.', style: AppTextStyles.caption),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _ActivityTile(item: items[i], isLast: i == items.length - 1, clockTime: clockTime),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, required this.isLast, required this.clockTime});

  final ActivityItem item;
  final bool isLast;
  final bool clockTime;

  String _subtitle(BuildContext context) {
    if (!clockTime || item.at == null) return item.subtitle;
    return [TimeOfDay.fromDateTime(item.at!).format(context), if (item.place != null) item.place!].join(' · ');
  }

  ({IconData icon, Color color, Color bg}) get _style => switch (item.type) {
        ActivityType.delivered => (
            icon: Icons.check_rounded,
            color: AppColors.success,
            bg: AppColors.successSoft
          ),
        ActivityType.pickupConfirmed => (
            icon: Icons.inventory_2_rounded,
            color: AppColors.warning,
            bg: AppColors.warningSoft
          ),
        ActivityType.arrived => (
            icon: Icons.navigation_rounded,
            color: AppColors.info,
            bg: AppColors.infoSoft
          ),
        ActivityType.outForDelivery => (
            icon: Icons.local_shipping_rounded,
            color: AppColors.info,
            bg: AppColors.infoSoft
          ),
        ActivityType.failed => (
            icon: Icons.close_rounded,
            color: AppColors.primaryDark,
            bg: AppColors.primarySoft
          ),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(color: s.bg, shape: BoxShape.circle),
                child: Icon(s.icon, size: 15, color: s.color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1.5, color: AppColors.border),
                ),
            ],
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppTextStyles.bodyStrong),
                  const SizedBox(height: 2),
                  Text(_subtitle(context), style: AppTextStyles.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
