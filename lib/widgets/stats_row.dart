import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/widgets/icon_tile.dart';
import 'package:rider_app/widgets/surface_card.dart';

class StatsRow extends StatelessWidget {
  const StatsRow({super.key, required this.pickups, required this.delivered});

  final int pickups;
  final int delivered;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
              icon: Icons.inventory_2_outlined,
              value: pickups,
              label: 'Pickups'),
        ),
        AppSpacing.gapMd,
        Expanded(
          child: _StatCard(
              icon: Icons.local_shipping_outlined,
              value: delivered,
              label: 'Delivered'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon),
          AppSpacing.gapMd,
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '$value ',
                  style: AppTextStyles.h2
                      .copyWith(color: AppColors.textPrimary)),
              TextSpan(text: label, style: AppTextStyles.bodyStrong),
            ]),
          ),
        ],
      ),
    );
  }
}
