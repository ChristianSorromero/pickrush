import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

/// What to collect at one stop, grouped by marketplace order. Read-only: the
/// rider confirms by scanning each waybill at the seller ([onAction]).
class OrdersToCollectScreen extends StatelessWidget {
  const OrdersToCollectScreen({
    super.key,
    required this.stop,
    this.actionLabel,
    this.onAction,
  });

  final BatchStop stop;

  /// e.g. "Navigate to stop" or "Scan waybills"; hidden when null.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // One card per order; a parcel without a marketplace order stands alone.
    final orders = <String, List<BatchItem>>{};
    for (final item in stop.items) {
      orders.putIfAbsent(item.orderNumber ?? item.trackingNo, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(stop.sellerName, style: AppTextStyles.h2.copyWith(fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH, vertical: AppSpacing.md),
        children: [
          Row(
            children: [
              Text('ORDERS TO COLLECT', style: AppTextStyles.overline),
              const Spacer(),
              Text(
                '${orders.length} ${orders.length == 1 ? 'order' : 'orders'} · '
                '${stop.items.length} ${stop.items.length == 1 ? 'parcel' : 'parcels'}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          if (stop.address != null) ...[
            const SizedBox(height: 4),
            Text(stop.address!, style: AppTextStyles.caption),
          ],
          AppSpacing.gapMd,
          for (final entry in orders.entries) ...[
            _OrderCard(
              title: entry.value.first.orderNumber != null
                  ? '#${entry.key}'
                  : entry.key,
              items: entry.value,
            ),
            AppSpacing.gapMd,
          ],
        ],
      ),
      bottomNavigationBar: actionLabel == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.lg),
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
                ),
                child: Text(actionLabel!),
              ),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.title, required this.items});
  final String title;
  final List<BatchItem> items;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.h2)),
              if (items.length > 1)
                TagChip.muted(label: '${items.length} parcels'),
            ],
          ),
          AppSpacing.gapSm,
          for (final item in items) _ParcelRow(item: item),
        ],
      ),
    );
  }
}

class _ParcelRow extends StatelessWidget {
  const _ParcelRow({required this.item});
  final BatchItem item;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (item.size != null) item.size!,
      if (item.weightKg != null) '${item.weightKg!.toStringAsFixed(1)} kg',
      if (item.size == null && item.weightKg == null && item.description != null)
        item.description!,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(item.trackingNo, style: AppTextStyles.bodyStrong),
              if (details.isNotEmpty)
                Expanded(
                  child: Text(' · ${details.join(' · ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption),
                )
              else
                const Spacer(),
              const SizedBox(width: 6),
              itemStatusChip(item.status),
            ],
          ),
          if (item.note != null)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2),
              child: Text(item.note!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark)),
            ),
        ],
      ),
    );
  }
}

Widget itemStatusChip(ItemStatus status) => switch (status) {
      ItemStatus.toPick => const TagChip(
          label: 'Expected', color: AppColors.info, background: AppColors.infoSoft),
      ItemStatus.pickedUp => const TagChip.success(label: 'Collected'),
      ItemStatus.received => const TagChip.success(label: 'Received'),
      ItemStatus.notCollected => const TagChip(label: 'Not collected'),
      ItemStatus.toLoad => const TagChip(
          label: 'To scan', color: AppColors.warning, background: AppColors.warningSoft),
      ItemStatus.loaded => const TagChip.success(label: 'Scanned'),
      ItemStatus.outForDelivery => const TagChip(
          label: 'On-going', color: AppColors.warning, background: AppColors.warningSoft),
      ItemStatus.delivered => const TagChip.success(label: 'Delivered'),
      ItemStatus.failed => const TagChip(label: 'Failed'),
      ItemStatus.returned => const TagChip.muted(label: 'Returned'),
    };
