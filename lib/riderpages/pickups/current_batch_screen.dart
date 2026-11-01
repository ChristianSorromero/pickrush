import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/pickups/new_assignment_screen.dart';
import 'package:rider_app/riderpages/pickups/orders_to_collect_screen.dart';
import 'package:rider_app/riderpages/pickups/scanner_screen.dart';
import 'package:rider_app/riderpages/pickups/stop_card.dart';
import 'package:rider_app/riderpages/pickups/trip_screen.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/icon_tile.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

/// An accepted batch: go stop by stop (navigate, arrive, scan each waybill),
/// then bring everything to the station.
class CurrentBatchScreen extends StatefulWidget {
  const CurrentBatchScreen({super.key, required this.batch});

  final RiderBatch batch;

  @override
  State<CurrentBatchScreen> createState() => _CurrentBatchScreenState();
}

class _CurrentBatchScreenState extends State<CurrentBatchScreen> {
  late RiderBatch _batch = widget.batch;
  int _seenChanges = assignmentWatcher.changes;

  @override
  void initState() {
    super.initState();
    assignmentWatcher.addListener(_onWatcher);
    _load();
  }

  @override
  void dispose() {
    assignmentWatcher.removeListener(_onWatcher);
    super.dispose();
  }

  // The station may take a parcel back while the rider is on this screen.
  void _onWatcher() {
    if (assignmentWatcher.changes != _seenChanges) {
      _seenChanges = assignmentWatcher.changes;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final batch = await riderTasks.batch(_batch.id);
      if (mounted) setState(() => _batch = batch);
    } on TaskException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  bool get _accepted => _batch.status == BatchStatus.accepted;

  /// Next step for a stop: the trip there, or the scanner once arrived.
  Future<void> _go(BatchStop stop) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => stop.hasArrived
          ? ScannerScreen(batch: _batch, stopNumber: stop.number)
          : TripScreen(batch: _batch, stopNumber: stop.number),
    ));
    _load();
  }

  Future<void> _openItems(BatchStop stop) async {
    final canAct = _accepted && !stop.isPickedUp;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => OrdersToCollectScreen(
        stop: stop,
        actionLabel: canAct ? (stop.hasArrived ? 'Scan waybills' : 'Navigate to stop') : null,
        onAction: canAct
            ? () {
                Navigator.of(context).pop();
                _go(stop);
              }
            : null,
      ),
    ));
  }

  Future<void> _headToHub() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => stationScreen(_batch)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final b = _batch;
    final next = b.nextStop;
    final finished = b.status == BatchStatus.completed;
    final closed = b.status == BatchStatus.cancelled;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Spacer(),
                  if (!finished && !closed)
                    TextButton.icon(
                      onPressed: () => openBatchRoute(context, b),
                      icon: const Icon(Icons.alt_route_rounded, size: 18),
                      label: const Text('Full route'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryDark),
                    ),
                ],
              ),
              AppSpacing.gapSm,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CURRENT BATCH', style: AppTextStyles.overline),
                        Text('#${b.batchNo}', style: AppTextStyles.h1),
                      ],
                    ),
                  ),
                  _statusChip(b),
                ],
              ),
              AppSpacing.gapLg,
              _Overview(batch: b),
              AppSpacing.gapXl,
              Text('PICKUP', style: AppTextStyles.overline),
              AppSpacing.gapMd,
              for (final stop in b.stops) ...[
                StopCard(
                  stop: stop,
                  highlight: identical(stop, next) && !closed,
                  status: stopStatusChip(stop, isNext: identical(stop, next)),
                  actions: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openItems(stop),
                          style: _outlined,
                          child: const Text('View items'),
                        ),
                      ),
                      if (!stop.isPickedUp && _accepted) ...[
                        AppSpacing.gapSm,
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _go(stop),
                            style: identical(stop, next) || stop.hasArrived ? _primary : _soft,
                            child: Text(stop.hasArrived ? 'Scan waybills' : 'Navigate'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AppSpacing.gapMd,
              ],
              if (b.dropOff != null) ...[
                AppSpacing.gapSm,
                Text('DROP-OFF', style: AppTextStyles.overline),
                AppSpacing.gapMd,
                DropOffCard(
                  dropOff: b.dropOff!,
                  actions: finished
                      ? Text('Received by the station. Batch complete!',
                          style: AppTextStyles.bodyStrong
                              .copyWith(color: AppColors.success))
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: b.allPickedUp && b.carrying > 0 ? _headToHub : null,
                            style: _primary,
                            child: Text(b.allPickedUp
                                ? (b.dropOff!.arrivedAt != null ? 'Open handover' : 'Head to station')
                                : 'Collect all stops first'),
                          ),
                        ),
                ),
              ],
              AppSpacing.gapLg,
            ],
          ),
        ),
      ),
    );
  }

  static Widget _statusChip(RiderBatch b) => switch (b.status) {
        BatchStatus.completed => const TagChip.success(label: 'Completed'),
        BatchStatus.cancelled => const TagChip.muted(label: 'Taken back'),
        _ when b.allPickedUp => const TagChip(
            label: 'Bring to station',
            color: Colors.white,
            background: AppColors.primary),
        _ when b.pickedCount > 0 => const TagChip(
            label: 'Picking up', color: Colors.white, background: AppColors.warning),
        _ => const TagChip(
            label: 'Ready for pickup',
            color: Colors.white,
            background: AppColors.warning),
      };

  static final _shape = RoundedRectangleBorder(borderRadius: AppRadius.mdAll);

  static final _outlined = OutlinedButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    side: const BorderSide(color: AppColors.border),
    shape: _shape,
    minimumSize: const Size.fromHeight(42),
  );

  static final _primary = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.primarySoft,
    disabledForegroundColor: AppColors.textMuted,
    elevation: 0,
    shape: _shape,
    minimumSize: const Size.fromHeight(42),
  );

  static final _soft = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primarySoft,
    foregroundColor: AppColors.primaryDark,
    elevation: 0,
    shape: _shape,
    minimumSize: const Size.fromHeight(42),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.batch});
  final RiderBatch batch;

  @override
  Widget build(BuildContext context) {
    final picked = batch.stops.where((s) => s.isPickedUp).length;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.location_on_outlined,
                  value: '$picked/${batch.stops.length}',
                  label: 'Stops done',
                ),
              ),
              Expanded(
                child: _Stat(
                  icon: Icons.inventory_2_outlined,
                  value: '${batch.pickedCount}/${batch.parcelCount}',
                  label: 'Parcels',
                ),
              ),
            ],
          ),
          if (batch.dropOff != null) ...[
            AppSpacing.gapMd,
            const Divider(height: 1, color: AppColors.border),
            AppSpacing.gapMd,
            Row(
              children: [
                const Icon(Icons.apartment_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Hub: ${batch.dropOff!.name}',
                      style: AppTextStyles.bodyStrong),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconTile(icon: icon, size: 36),
        AppSpacing.gapSm,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTextStyles.h2),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ],
    );
  }
}
