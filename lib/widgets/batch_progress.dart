import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/batch_models.dart';

/// ASSIGNED — PICKUP — DROPPED OFF (pickup) or ASSIGNED — PICKUP — DELIVER
/// (delivery, where "pickup" is loading at the station), filled up to the stage.
class BatchProgress extends StatelessWidget {
  const BatchProgress({super.key, required this.stage, this.delivery = false});

  final BatchStage stage;
  final bool delivery;

  @override
  Widget build(BuildContext context) {
    final labels = delivery
        ? const ['ASSIGNED', 'PICKUP', 'DELIVER']
        : const ['ASSIGNED', 'PICKUP', 'DROPPED OFF'];
    final reached = switch (stage) {
      BatchStage.assigned => 0,
      BatchStage.pickup => 1,
      BatchStage.deliver || BatchStage.droppedOff => 2,
    };
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              _Dot(done: i <= reached),
              if (i < labels.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < reached ? AppColors.primary : AppColors.border,
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < labels.length; i++)
              Text(
                labels[i],
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: i <= reached ? AppColors.primaryDark : AppColors.textMuted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      width: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.primary : AppColors.surface,
        border: Border.all(
            color: done ? AppColors.primary : AppColors.border, width: 2),
      ),
    );
  }
}
