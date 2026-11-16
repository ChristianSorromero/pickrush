import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';

/// Small status label: NEXT, PENDING, PICKUP 1... Named constructors follow
/// the task tones (see [TaskTone]).
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.color = AppColors.primaryDark,
    this.background = AppColors.primarySoft,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final Color background;
  final bool outlined;

  TagChip.tone({super.key, required this.label, required TaskTone tone})
      : color = tone.color,
        background = tone.soft,
        outlined = false;

  const TagChip.warning({super.key, required this.label})
      : color = AppColors.warning,
        background = AppColors.warningSoft,
        outlined = false;

  const TagChip.success({super.key, required this.label})
      : color = AppColors.success,
        background = AppColors.successSoft,
        outlined = false;

  const TagChip.info({super.key, required this.label})
      : color = AppColors.info,
        background = AppColors.infoSoft,
        outlined = false;

  const TagChip.error({super.key, required this.label})
      : color = AppColors.errorStrong,
        background = AppColors.errorSoft,
        outlined = false;

  const TagChip.muted({super.key, required this.label})
      : color = AppColors.textSecondary,
        background = AppColors.surface,
        outlined = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillAll,
        border: outlined ? Border.all(color: AppColors.border) : null,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          height: 1.2,
        ),
      ),
    );
  }
}
