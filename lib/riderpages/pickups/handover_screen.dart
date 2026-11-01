import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/handover_parts.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';

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
    final items = b.collected;
    bool isReceived(BatchItem i) => i.status == ItemStatus.received;
    final received = items.where(isReceived).length;
    final complete = b.status == BatchStatus.completed;

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
              HandoverHeader(batch: b, done: received, total: items.length, complete: complete),
              AppSpacing.gapLg,
              HandoverStep(
                number: null,
                title: 'Hand over parcels',
                done: received == items.length,
                status: received == items.length ? 'All received' : '${items.length - received} waiting',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!complete)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text('Give each parcel to the staff. They scan it in.', style: AppTextStyles.caption),
                      ),
                    ParcelChecklist(items: items, isDone: isReceived),
                  ],
                ),
              ),
              if (b.notCollectedCount > 0) ...[
                AppSpacing.gapSm,
                Text(
                  '${b.notCollectedCount} not collected: the station will reassign ${b.notCollectedCount == 1 ? 'it' : 'them'}.',
                  style: AppTextStyles.caption,
                ),
              ],
              AppSpacing.gapLg,
              HandoverFooter(complete: complete),
            ],
          ),
        ),
      ),
    );
  }
}
