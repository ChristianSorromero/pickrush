import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/handover_parts.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';

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
    final complete = b.status == BatchStatus.completed;
    final returns = b.returns;
    bool isReturned(BatchItem i) => i.status == ItemStatus.returned;
    final returned = returns.where(isReturned).length;
    final hasCash = b.codCollected > 0;
    final cashDone = !hasCash || b.remitted;

    // Progress: the cash counts as one step, each parcel as one.
    final total = (hasCash ? 1 : 0) + returns.length;
    final done = (hasCash && b.remitted ? 1 : 0) + returned;
    var step = 0;

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
              HandoverHeader(batch: b, done: done, total: total, complete: complete),
              AppSpacing.gapSm,
              Text('${b.deliveredCount} delivered · ${b.failedCount} not delivered', style: AppTextStyles.caption),
              AppSpacing.gapLg,
              if (hasCash) ...[
                HandoverStep(
                  number: ++step,
                  title: 'Hand over cash',
                  done: cashDone,
                  status: cashDone ? 'Remitted' : 'Waiting',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(FormatUtils.peso(b.remitted ? b.codCollected : b.toRemit),
                          style: AppTextStyles.display.copyWith(fontSize: 26)),
                      if (!cashDone)
                        Text('Give the COD cash to the station cashier. They count it and record it.',
                            style: AppTextStyles.caption),
                    ],
                  ),
                ),
                AppSpacing.gapMd,
              ],
              if (returns.isNotEmpty) ...[
                HandoverStep(
                  number: ++step,
                  title: 'Hand back parcels',
                  done: returned == returns.length,
                  status: returned == returns.length ? 'All received' : '${returns.length - returned} waiting',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!complete)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text('Parcels you could not deliver. The staff scan each one in at Receiving.',
                              style: AppTextStyles.caption),
                        ),
                      ParcelChecklist(items: returns, isDone: isReturned),
                    ],
                  ),
                ),
                AppSpacing.gapMd,
              ],
              if (!hasCash && returns.isEmpty)
                Text('Everything was delivered and there is no cash to remit.', style: AppTextStyles.body),
              AppSpacing.gapMd,
              HandoverFooter(complete: complete),
            ],
          ),
        ),
      ),
    );
  }
}
