import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/pickups/batch_routes.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/app_feedback.dart';
import 'package:rider_app/widgets/motion.dart';

/// Which open batches a [BatchList] shows.
enum BatchFilter {
  offers,
  pickups,
  deliveries;

  bool matches(RiderBatch b) => switch (this) {
        BatchFilter.offers => b.isOffer,
        BatchFilter.pickups => !b.isOffer && !b.isDelivery,
        BatchFilter.deliveries => !b.isOffer && b.isDelivery,
      };
}

/// What a batch is doing now, in a few words.
String batchProgressLabel(RiderBatch b) {
  if (b.isOffer) return 'New offer';
  if (!b.isDelivery) return b.allPickedUp ? 'Bring to station' : 'Picking up';
  if (!b.hasStarted) return 'Load at station';
  return b.allStopsDone ? 'Return to hub' : 'Out for delivery';
}

TaskTone batchTone(RiderBatch b) => switch (b.status) {
      BatchStatus.offered => TaskTone.offer,
      BatchStatus.completed => TaskTone.done,
      BatchStatus.cancelled || BatchStatus.declined => TaskTone.muted,
      BatchStatus.accepted => TaskTone.active,
    };

/// Open batches of one kind (offers, pickups or deliveries) from
/// `/api/rider/batches`; reloads when the station sends something.
class BatchList extends StatefulWidget {
  const BatchList({super.key, required this.filter});

  final BatchFilter filter;

  @override
  State<BatchList> createState() => _BatchListState();
}

class _BatchListState extends State<BatchList> {
  List<RiderBatch>? _batches;
  String? _error;
  bool _offline = false;
  int _seenChanges = -1;

  @override
  void initState() {
    super.initState();
    assignmentWatcher.addListener(_onWatcher);
    _load();
  }

  @override
  void didUpdateWidget(BatchList old) {
    super.didUpdateWidget(old);
    if (old.filter != widget.filter) _load();
  }

  @override
  void dispose() {
    assignmentWatcher.removeListener(_onWatcher);
    super.dispose();
  }

  void _onWatcher() {
    if (assignmentWatcher.changes != _seenChanges) _load();
  }

  Future<void> _load() async {
    _seenChanges = assignmentWatcher.changes;
    try {
      final batches = (await riderTasks.batches()).where(widget.filter.matches).toList();
      if (mounted) {
        setState(() {
          _batches = batches;
          _error = null;
        });
      }
    } on TaskException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _offline = e.offline;
        });
      }
    }
  }

  Future<void> _open(RiderBatch b) async {
    await openBatch(context, b);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final batches = _batches;
    final Widget body;
    if (batches == null && _error == null) {
      body = const StateView.loading(skeleton: CardListSkeleton());
    } else if (batches == null) {
      body = StateView.error(message: _error!, offline: _offline, onRetry: _load);
    } else if (batches.isEmpty) {
      body = StateView.empty(
        icon: switch (widget.filter) {
          BatchFilter.offers => Icons.mark_email_read_outlined,
          BatchFilter.pickups => Icons.inventory_2_outlined,
          BatchFilter.deliveries => Icons.local_shipping_outlined,
        },
        title: switch (widget.filter) {
          BatchFilter.offers => 'No new offers',
          BatchFilter.pickups => 'No pickups in progress',
          BatchFilter.deliveries => 'No deliveries in progress',
        },
        message: 'You will be notified when your station assigns one.',
      );
    } else {
      body = FadeIn(
        child: Column(
          children: [
            for (final b in batches) ...[
              BatchCard(batch: b, onTap: () => _open(b)),
              AppSpacing.gapMd,
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xxl),
        children: [body],
      ),
    );
  }
}

/// One batch: a status rail in its tone, number and state, progress, and
/// where to go next.
class BatchCard extends StatelessWidget {
  const BatchCard({super.key, required this.batch, required this.onTap});
  final RiderBatch batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = batchTone(batch);
    final next = batch.nextStop;
    final done = batch.isDelivery ? batch.deliveredCount + batch.failedCount : batch.pickedCount;
    final stops = batch.stops.length;
    final where = next == null
        ? null
        : batch.isOffer
            ? batch.stops.map((s) => s.name).join(', ')
            : batch.isDelivery && !batch.hasStarted
                ? 'Scan the parcels at the station'
                : 'Next: ${next.name}';

    return Pressable(
      scale: 0.98,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll, side: const BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: tone.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.sm, AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(batch.isDelivery ? Icons.local_shipping_rounded : Icons.inventory_2_rounded,
                                size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('#${batch.batchNo}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.numeric),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(child: ToneChip(label: batchProgressLabel(batch), tone: tone)),
                          ],
                        ),
                        AppSpacing.gapSm,
                        Text(
                          '$stops ${stops == 1 ? 'stop' : 'stops'} · '
                          '${batch.isOffer ? '${batch.parcelCount} parcels' : '$done/${batch.parcelCount} ${batch.isDelivery ? 'done' : 'collected'}'}',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        if (!batch.isOffer && batch.parcelCount > 0) ...[
                          AppSpacing.gapSm,
                          ClipRRect(
                            borderRadius: AppRadius.pillAll,
                            child: LinearProgressIndicator(
                              value: done / batch.parcelCount,
                              minHeight: 5,
                              color: tone.color,
                              backgroundColor: AppColors.surfaceMuted,
                            ),
                          ),
                        ],
                        if (where != null) ...[
                          AppSpacing.gapMd,
                          Row(
                            children: [
                              Icon(batch.isDelivery ? Icons.location_on_rounded : Icons.storefront_rounded,
                                  size: 16, color: AppColors.primaryDark),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(where,
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyStrong),
                              ),
                            ],
                          ),
                        ],
                        if (batch.isDelivery && batch.codTotal > 0) ...[
                          AppSpacing.gapSm,
                          ToneChip(label: 'COD ${FormatUtils.peso(batch.codTotal)}', tone: TaskTone.attention),
                        ],
                      ],
                    ),
                  ),
                ),
                const Center(child: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded status label in a [TaskTone].
class ToneChip extends StatelessWidget {
  const ToneChip({super.key, required this.label, required this.tone});
  final String label;
  final TaskTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: tone.soft, borderRadius: AppRadius.pillAll),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.label.copyWith(fontSize: 12, color: tone.color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
