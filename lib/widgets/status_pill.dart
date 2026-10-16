import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';

/// Rounded chip with a leading widget and a label (ONLINE, hub name, etc).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.leading});

  final String label;
  final Widget leading;

  /// Green dot variant, e.g. ONLINE.
  factory StatusPill.dot({
    Key? key,
    required String label,
    Color color = AppColors.success,
  }) =>
      StatusPill(
        key: key,
        label: label,
        leading: Container(
          height: 18,
          width: 18,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Center(
            child: CircleAvatar(radius: 3, backgroundColor: Colors.white),
          ),
        ),
      );

  /// Icon variant, e.g. sorting center.
  factory StatusPill.icon({
    Key? key,
    required String label,
    required IconData icon,
  }) =>
      StatusPill(
        key: key,
        label: label,
        leading: Icon(icon, size: 14, color: AppColors.textPrimary),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
