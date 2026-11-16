import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/pickups/pickups_screen.dart';
import 'package:rider_app/widgets/motion.dart';

/// Sits above the bottom tabs while a batch is in progress, so the rider is
/// one tap from their current work on any tab.
class ActiveTaskBar extends StatelessWidget {
  const ActiveTaskBar({super.key, required this.batch, required this.onOpen, this.moreCount = 0});

  /// The batch in progress, or null to hide the bar.
  final RiderBatch? batch;
  final VoidCallback onOpen;

  /// Other accepted batches besides [batch].
  final int moreCount;

  @override
  Widget build(BuildContext context) {
    final b = batch;
    return AnimatedSize(
      duration: AppMotion.duration(context, AppMotion.small),
      curve: AppMotion.change,
      alignment: Alignment.bottomCenter,
      child: b == null ? const SizedBox(width: double.infinity) : _bar(context, b),
    );
  }

  Widget _bar(BuildContext context, RiderBatch b) {
    final stops = b.stops.length;
    final doneStops = b.stops.where((s) => s.isDone).length;
    final where = !b.hasStarted && b.isDelivery
        ? 'Load at station'
        : b.allStopsDone
            ? (b.isDelivery ? 'Return to hub' : 'Bring to station')
            : 'Stop ${doneStops + 1} of $stops';
    final label = '${b.isDelivery ? 'Delivery' : 'Pickup'} #${b.batchNo} · $where';

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
      child: Semantics(
        button: true,
        label: 'Continue $label',
        excludeSemantics: true,
        child: Pressable(
          scale: 0.98,
          child: Material(
            color: AppColors.textPrimary,
            borderRadius: AppRadius.lgAll,
            child: InkWell(
              borderRadius: AppRadius.lgAll,
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: Icon(b.isDelivery ? Icons.local_shipping_rounded : Icons.inventory_2_rounded,
                          size: 20, color: AppColors.onPrimary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            batchProgressLabel(b).toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.overline.copyWith(color: AppColors.primary, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          ValueSwap(
                            value: label,
                            child: Text(
                              label + (moreCount > 0 ? '  +$moreCount' : ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyStrong.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: AppSize.minTap,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.button),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Continue',
                              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15),
                              style: AppTextStyles.label.copyWith(color: AppColors.onPrimary)),
                          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.onPrimary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
