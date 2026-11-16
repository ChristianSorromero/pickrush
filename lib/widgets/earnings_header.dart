import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/widgets/motion.dart';

/// Today in one card: what the rider earned and the tasks behind it.
class EarningsHeader extends StatelessWidget {
  const EarningsHeader({super.key, required this.amount, required this.pickups, required this.delivered});

  final double amount;
  final int pickups;
  final int delivered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: AppRadius.lgAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TODAY'S EARNINGS", style: AppTextStyles.overline.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          ValueSwap(
            value: amount,
            child: Text(FormatUtils.peso(amount), style: AppTextStyles.display.copyWith(color: Colors.white)),
          ),
          AppSpacing.gapLg,
          Row(
            children: [
              Expanded(child: _Stat(icon: Icons.inventory_2_rounded, value: pickups, label: 'Picked up')),
              Container(width: 1, height: 32, color: Colors.white24),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: _Stat(icon: Icons.check_circle_rounded, value: delivered, label: 'Delivered')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          ValueSwap(value: value, child: Text('$value', style: AppTextStyles.numeric.copyWith(color: Colors.white, fontSize: 20))),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white70))),
        ],
      ),
    );
  }
}
