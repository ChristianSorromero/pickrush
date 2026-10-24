import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/services/launcher.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

/// One seller to collect from. [tag] sits top-left (PICKUP 1) and [status]
/// top-right (NEXT / PENDING / PICKED UP); [actions] go at the bottom.
class StopCard extends StatelessWidget {
  const StopCard({
    super.key,
    required this.stop,
    this.tag,
    this.status,
    this.actions,
    this.highlight = false,
  });

  final BatchStop stop;
  final Widget? tag;
  final Widget? status;
  final Widget? actions;

  /// The stop the rider should go to now.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: highlight
          ? BoxDecoration(
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: AppColors.primary, width: 1.5),
            )
          : null,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tag != null || status != null) ...[
              Row(
                children: [
                  if (tag != null) tag!,
                  const Spacer(),
                  if (status != null) status!,
                ],
              ),
              AppSpacing.gapSm,
            ],
            Text(stop.sellerName, style: AppTextStyles.h2),
            if (stop.address != null) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(stop.address!, style: AppTextStyles.caption)),
                ],
              ),
            ],
            AppSpacing.gapSm,
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  [
                    stop.pickedCount > 0 && !stop.isPickedUp
                        ? '${stop.pickedCount} of ${stop.parcelCount} parcels collected'
                        : '${stop.parcelCount} ${stop.parcelCount == 1 ? 'parcel' : 'parcels'}',
                    if (stop.notCollectedCount > 0) '${stop.notCollectedCount} not collected',
                    if (stop.kind == 'delivery' && stop.codTotal > 0) 'COD ${FormatUtils.peso(stop.codTotal)}',
                    if (stop.hasArrived && !stop.isPickedUp) 'arrived',
                  ].join(' · '),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const Spacer(),
                if (stop.sellerMobile != null && !stop.isPickedUp)
                  InkWell(
                    onTap: () => Launcher.call(stop.sellerMobile!),
                    borderRadius: AppRadius.pillAll,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          const Icon(Icons.call_outlined,
                              size: 14, color: AppColors.primaryDark),
                          const SizedBox(width: 4),
                          Text(stop.kind == 'delivery' ? 'Call buyer' : 'Call seller',
                              style: AppTextStyles.link.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (actions != null) ...[AppSpacing.gapMd, actions!],
          ],
        ),
      ),
    );
  }
}

/// Status chip for a stop inside an accepted batch.
Widget stopStatusChip(BatchStop stop, {required bool isNext}) {
  if (stop.isPickedUp) return const TagChip.success(label: 'Picked up');
  if (isNext) return const TagChip.warning(label: 'Next');
  return const TagChip.muted(label: 'Pending');
}
