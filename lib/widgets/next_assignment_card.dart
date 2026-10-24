import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/widgets/app_button.dart';
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

    return InkWell(
      onTap: onOpen,
      borderRadius: AppRadius.lgAll,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _tag(b),
                const Spacer(),
                const Icon(Icons.location_on_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text('${b.stops.length} ${b.stops.length == 1 ? 'Stop' : 'Stops'}',
                    style: AppTextStyles.bodyStrong),
              ],
            ),
            AppSpacing.gapMd,
            Text('Batch #${b.batchNo}',
                style: AppTextStyles.h2.copyWith(fontSize: 20)),
            AppSpacing.gapMd,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(
                    icon: b.isDelivery ? Icons.location_on_rounded : Icons.storefront_rounded,
                    size: 36),
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
                  Text('Estimated Earning', style: AppTextStyles.body),
                  const Spacer(),
                  Text(FormatUtils.peso(b.estEarnings),
                      style: AppTextStyles.h2
                          .copyWith(color: AppColors.primaryDark)),
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
    );
  }
}

/// READY FOR PICKUP / READY FOR DELIVERY on an offer, then where the batch is.
Widget _tag(RiderBatch b) {
  if (b.isOffer) {
    return TagChip.warning(label: b.isDelivery ? 'New · Ready for delivery' : 'New · Ready for pickup');
  }
  if (!b.isDelivery) {
    return TagChip.success(label: b.allPickedUp ? 'Bring to station' : 'In progress');
  }
  if (!b.hasStarted) return const TagChip.warning(label: 'Load at station');
  return TagChip.success(label: b.allStopsDone ? 'Return to hub' : 'Out for delivery');
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
          Icon(
            isOnline ? Icons.inventory_2_outlined : Icons.power_settings_new_rounded,
            size: 32,
            color: AppColors.textMuted,
          ),
          AppSpacing.gapSm,
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
