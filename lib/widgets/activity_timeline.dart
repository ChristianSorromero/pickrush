import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/dashboard_models.dart';

class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({super.key, required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _ActivityTile(item: items[i], isLast: i == items.length - 1),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, required this.isLast});

  final ActivityItem item;
  final bool isLast;

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
                  Text(item.subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
