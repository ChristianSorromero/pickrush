import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

/// At the station after a delivery route: hand in the COD cash (the station
/// records it on its Cash page) and each parcel not delivered (they scan it in
/// at Receiving). Both tick off here as the station does them.
class ReturnHandoverScreen extends StatefulWidget {
  const ReturnHandoverScreen({super.key, required this.batch});

  final RiderBatch batch;

  @override
  State<ReturnHandoverScreen> createState() => _ReturnHandoverScreenState();
}

class _ReturnHandoverScreenState extends State<ReturnHandoverScreen> {
  late RiderBatch _batch = widget.batch;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _refresh());
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final batch = await riderTasks.batch(_batch.id);
      if (!mounted) return;
      setState(() => _batch = batch);
      if (batch.status == BatchStatus.completed) {
        _timer?.cancel();
        assignmentWatcher.poll();
      }
    } on TaskException {
      // Try again on the next tick.
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _batch;
    final done = b.status == BatchStatus.completed;
    final returns = b.returns;
    final hasCash = b.codCollected > 0;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Text(done ? 'Batch complete!' : 'Hand over at the station', style: AppTextStyles.h1),
              Text('#${b.batchNo} · ${b.dropOff?.name ?? ''}', style: AppTextStyles.body),
              AppSpacing.gapLg,
              if (done)
                SurfaceCard(
                  child: Column(
                    children: [
                      const Icon(Icons.verified_rounded, size: 44, color: AppColors.success),
                      AppSpacing.gapSm,
                      Text('${b.deliveredCount} delivered · ${b.failedCount} returned', style: AppTextStyles.h2),
                      if (b.estEarnings > 0) ...[
                        AppSpacing.gapSm,
                        Text('You earned ${FormatUtils.peso(b.estEarnings)} on this batch',
                            style: AppTextStyles.bodyStrong.copyWith(color: AppColors.success)),
                      ],
                    ],
                  ),
                ),
              if (done) AppSpacing.gapLg,
              Text('CASH', style: AppTextStyles.overline),
              AppSpacing.gapSm,
              SurfaceCard(
                child: Row(
                  children: [
                    Icon(
                      !hasCash || b.remitted ? Icons.check_circle_rounded : Icons.payments_outlined,
                      color: !hasCash || b.remitted ? AppColors.success : AppColors.primaryDark,
                    ),
                    AppSpacing.gapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            !hasCash
                                ? 'No cash to remit'
                                : b.remitted
                                    ? '${FormatUtils.peso(b.codCollected)} remitted'
                                    : 'Remit ${FormatUtils.peso(b.toRemit)}',
                            style: AppTextStyles.bodyStrong,
                          ),
                          if (hasCash && !b.remitted)
                            Text('Hand the cash to the station cashier. They count it and record it.',
                                style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    if (hasCash)
                      b.remitted
                          ? const TagChip.success(label: 'Remitted')
                          : const TagChip.warning(label: 'Waiting'),
                  ],
                ),
              ),
              AppSpacing.gapLg,
              Text('PARCELS TO RETURN', style: AppTextStyles.overline),
              AppSpacing.gapSm,
              if (returns.isEmpty)
                SurfaceCard(child: Text('Everything was delivered. Nothing to return.', style: AppTextStyles.body))
              else
                for (final item in returns)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SurfaceCard(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(
                            item.status == ItemStatus.returned ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: item.status == ItemStatus.returned ? AppColors.success : AppColors.textMuted,
                          ),
                          AppSpacing.gapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.trackingNo, style: AppTextStyles.bodyStrong),
                                if (item.note != null) Text(item.note!, style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          item.status == ItemStatus.returned
                              ? const TagChip.success(label: 'Received')
                              : Text('Waiting for scan', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  ),
              if (!done) ...[
                AppSpacing.gapSm,
                Text('This page updates as the station records the cash and scans the parcels.',
                    textAlign: TextAlign.center, style: AppTextStyles.caption),
              ],
              if (done) ...[
                AppSpacing.gapLg,
                AppButton(
                  label: 'Back to home',
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
