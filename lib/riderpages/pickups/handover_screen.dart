import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/pickups/orders_to_collect_screen.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/surface_card.dart';

/// At the station: each parcel ticks to "Received" as the staff scan it in.
/// When all are in, the batch is done.
class HandoverScreen extends StatefulWidget {
  const HandoverScreen({super.key, required this.batch});

  final RiderBatch batch;

  @override
  State<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends State<HandoverScreen> {
  late RiderBatch _batch = widget.batch;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _refresh());
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
    final items = _batch.collected;
    final received = items.where((i) => i.status == ItemStatus.received).length;
    final done = _batch.status == BatchStatus.completed;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Text(done ? 'Batch complete!' : 'Hand over to station staff', style: AppTextStyles.h1),
              Text('Batch #${_batch.batchNo} · ${_batch.dropOff?.name ?? ''}', style: AppTextStyles.body),
              AppSpacing.gapLg,
              SurfaceCard(
                child: Column(
                  children: [
                    Icon(done ? Icons.verified_rounded : Icons.qr_code_scanner_rounded,
                        size: 44, color: done ? AppColors.success : AppColors.primary),
                    AppSpacing.gapSm,
                    Text('$received / ${items.length}',
                        style: AppTextStyles.display.copyWith(fontSize: 30)),
                    Text(done ? 'All parcels received by the station' : 'parcels received by the station',
                        style: AppTextStyles.body),
                    if (done && _batch.estEarnings > 0) ...[
                      AppSpacing.gapSm,
                      Text('You earned ${FormatUtils.peso(_batch.estEarnings)} on this batch',
                          style: AppTextStyles.bodyStrong.copyWith(color: AppColors.success)),
                    ],
                    if (!done) ...[
                      AppSpacing.gapSm,
                      Text('Give each parcel to the staff. This list updates as they scan.',
                          textAlign: TextAlign.center, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
              AppSpacing.gapLg,
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: SurfaceCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          item.status == ItemStatus.received
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: item.status == ItemStatus.received ? AppColors.success : AppColors.textMuted,
                        ),
                        AppSpacing.gapMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.trackingNo, style: AppTextStyles.bodyStrong),
                              if (item.orderNumber != null)
                                Text('Order #${item.orderNumber}', style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        item.status == ItemStatus.received
                            ? itemStatusChip(ItemStatus.received)
                            : Text('Waiting for scan', style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ),
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
