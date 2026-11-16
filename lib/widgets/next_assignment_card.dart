import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/pickups/pickups_screen.dart' show batchProgressLabel;
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/motion.dart';
import 'package:rider_app/widgets/batch_progress.dart';
import 'package:rider_app/widgets/icon_tile.dart';
import 'package:rider_app/widgets/slide_to_accept.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

/// The batch the rider should deal with next: an offer to accept, or the batch
/// in progress. Shows an empty state when there is none.
class NextAssignmentCard extends StatelessWidget {
  const NextAssignmentCard({
    super.key,
    this.batch,
    this.isOnline = true,
    this.onOpen,
    this.onAccept,
  });

  final RiderBatch? batch;
  final bool isOnline;
  final VoidCallback? onOpen;

  /// Called by the slider on an offer. Throw to reset the slider.
  final Future<void> Function()? onAccept;

  @override
  Widget build(BuildContext context) {
    final b = batch;
    if (b == null) return _Empty(isOnline: isOnline);

    final next = b.nextStop ?? b.stops.first;
    final more = b.stops.length - 1;

    final tone = b.isOffer ? TaskTone.offer : TaskTone.active;
    return Pressable(
      scale: 0.98,
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll, side: const BorderSide(color: AppColors.border)),
        child: InkWell(
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: tone.color, width: 4))),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(child: _tag(b)),
                const Spacer(),
                const Icon(Icons.location_on_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text('${b.stops.length} ${b.stops.length == 1 ? 'Stop' : 'Stops'}',
                    style: AppTextStyles.bodyStrong),
              ],
            ),
            AppSpacing.gapMd,
            Text('Batch #${b.batchNo}', style: AppTextStyles.numeric.copyWith(fontSize: 20)),
            AppSpacing.gapMd,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(
                    icon: b.isDelivery ? Icons.location_on_rounded : Icons.storefront_rounded,
                    color: tone.color,
                    background: tone.soft,
                    size: 40),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(next.name, style: AppTextStyles.bodyStrong),
                      if (next.address != null)
                        Text(next.address!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption),
                      Text(
                        '${next.parcelCount} ${next.parcelCount == 1 ? 'parcel' : 'parcels'}'
                        '${b.isDelivery && next.codTotal > 0 ? ' · COD ${FormatUtils.peso(next.codTotal)}' : ''}'
                        '${more > 0 ? ' · +$more more ${more == 1 ? 'stop' : 'stops'}' : ''}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.gapLg,
            BatchProgress(stage: b.stage, delivery: b.isDelivery),
            if (b.estEarnings > 0) ...[
              AppSpacing.gapLg,
              const Divider(height: 1, color: AppColors.border),
              AppSpacing.gapMd,
              Row(
                children: [
                  Expanded(child: Text('Estimated earning', style: AppTextStyles.body)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(FormatUtils.peso(b.estEarnings),
                      style: AppTextStyles.numeric.copyWith(color: AppColors.success, fontSize: 17)),
                ],
              ),
            ],
            AppSpacing.gapLg,
            if (b.isOffer && onAccept != null)
              SlideToAccept(onSubmit: onAccept!)
            else
              AppButton(
                label: b.isOffer ? 'Review assignment' : 'Continue batch',
                onPressed: onOpen,
              ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}

/// READY FOR PICKUP / READY FOR DELIVERY on an offer, then where the batch is.
Widget _tag(RiderBatch b) {
  if (b.isOffer) {
    return TagChip.info(label: b.isDelivery ? 'New · Delivery offer' : 'New · Pickup offer');
  }
  return TagChip.tone(label: batchProgressLabel(b), tone: TaskTone.active);
}

class _Empty extends StatelessWidget {
  const _Empty({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.surfaceMuted, shape: BoxShape.circle),
            child: Icon(
              isOnline ? Icons.inventory_2_outlined : Icons.power_settings_new_rounded,
              size: 26,
              color: AppColors.textSecondary,
            ),
          ),
          AppSpacing.gapMd,
          Text('No assignment yet', style: AppTextStyles.bodyStrong),
          const SizedBox(height: 2),
          Text(
            isOnline
                ? "You're online. New pickups from your station appear here."
                : "You're offline. Go online to receive pickups.",
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
