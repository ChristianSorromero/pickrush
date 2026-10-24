import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/deliveries/deliver_screen.dart';
import 'package:rider_app/riderpages/deliveries/load_scan_sheet.dart';
import 'package:rider_app/riderpages/deliveries/return_to_hub_screen.dart';
import 'package:rider_app/riderpages/pickups/new_assignment_screen.dart';
import 'package:rider_app/riderpages/pickups/orders_to_collect_screen.dart';
import 'package:rider_app/riderpages/pickups/report_problem_sheet.dart';
import 'package:rider_app/riderpages/pickups/trip_screen.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

/// An accepted delivery batch. Before the route: scan every parcel onto the
/// vehicle at the station, then Start Route. On the route: stop by stop
/// (navigate, arrive, scan, deliver or fail), then Return to Hub.
class DeliveryBatchScreen extends StatefulWidget {
  const DeliveryBatchScreen({super.key, required this.batch});

  final RiderBatch batch;

  @override
  State<DeliveryBatchScreen> createState() => _DeliveryBatchScreenState();
}

class _DeliveryBatchScreenState extends State<DeliveryBatchScreen> {
  late RiderBatch _batch = widget.batch;
  int _seenChanges = assignmentWatcher.changes;
  bool _starting = false;

  // One key for every retry of "Start Route" from this screen.
  late final String _startKey = 'b${widget.batch.id}-start-${DateTime.now().microsecondsSinceEpoch}';

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
      _toast(e.message);
    }
  }

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _scan() async {
    final updated = await showLoadScanSheet(context, _batch);
    if (updated != null && mounted) setState(() => _batch = updated);
  }

  Future<void> _startRoute() async {
    final missing = _batch.items.where((i) => !i.isLoaded).length;
    String? reason;
    if (missing > 0) {
      reason = await _askLeaveBehind(missing);
      if (reason == null) return;
    }
    setState(() => _starting = true);
    try {
      final batch = await riderTasks.startRoute(_batch.id, leaveBehindReason: reason, requestKey: _startKey);
      assignmentWatcher.poll();
      if (!mounted) return;
      setState(() => _batch = batch);
      _toast('Route started. Your parcels are out for delivery.');
    } on TaskException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<String?> _askLeaveBehind(int missing) {
    final note = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('$missing ${missing == 1 ? 'parcel' : 'parcels'} not scanned'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Start without ${missing == 1 ? 'it' : 'them'}? ${missing == 1 ? 'It goes' : 'They go'} back to the station\'s queue.',
                  style: AppTextStyles.body),
              AppSpacing.gapMd,
              TextField(
                controller: note,
                autofocus: true,
                onChanged: (_) => setDialog(() {}),
                decoration: const InputDecoration(hintText: 'Why? e.g. not on the shelf'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep scanning')),
            TextButton(
              onPressed: note.text.trim().isEmpty ? null : () => Navigator.pop(context, note.text.trim()),
              child: const Text('Start without'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _go(BatchStop stop) async {
    final result = await Navigator.of(context).push<RiderBatch>(MaterialPageRoute(
      builder: (_) => stop.hasArrived
          ? DeliverScreen(batch: _batch, stopNumber: stop.number)
          : TripScreen(batch: _batch, stopNumber: stop.number),
    ));
    if (result != null && mounted) setState(() => _batch = result);
    _load();
  }

  Future<void> _returnToHub() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReturnToHubScreen(batch: _batch)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final b = _batch;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: b.hasStarted ? _route(b) : _loadOut(b),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.md),
        child: b.hasStarted ? _routeButtons(b) : _loadButtons(b),
      ),
    );
  }

  // Loading at the station ------------------------------------------------------

  Widget _loadOut(RiderBatch b) {
    final loaded = b.items.where((i) => i.isLoaded).length;
    final total = b.items.length;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
      children: [
        _BackRow(onReport: () => showReportProblem(context, b.id)),
        Text('Deliveries', style: AppTextStyles.h1),
        Text('Scan every parcel in your batch before you start the route.', style: AppTextStyles.body),
        AppSpacing.gapLg,
        _BatchSummary(batch: b, footer: Row(
          children: [
            Text('$loaded of $total parcels scanned', style: AppTextStyles.bodyStrong),
            const Spacer(),
            loaded == total
                ? const TagChip.success(label: 'Ready to go')
                : const TagChip.muted(label: 'Not started'),
          ],
        )),
        AppSpacing.gapXl,
        Text('Parcels', style: AppTextStyles.h2),
        AppSpacing.gapMd,
        for (final stop in b.stops)
          for (final item in stop.items) ...[
            _ParcelTile(stop: stop, item: item),
            AppSpacing.gapSm,
          ],
      ],
    );
  }

  Widget _loadButtons(RiderBatch b) {
    final loaded = b.items.where((i) => i.isLoaded).length;
    final total = b.items.length;
    final missing = total - loaded;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: missing == 0 ? null : _scan,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scan Parcel'),
          style: _primary,
        ),
        AppSpacing.gapSm,
        OutlinedButton(
          onPressed: loaded == 0 || _starting ? null : _startRoute,
          style: _outlined.copyWith(
            backgroundColor: WidgetStatePropertyAll(missing == 0 ? AppColors.primarySoft : null),
          ),
          child: _starting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(missing == 0 ? 'Start Route' : 'Start Route ($missing not scanned)'),
        ),
      ],
    );
  }

  // On the route ------------------------------------------------------------------

  Widget _route(RiderBatch b) {
    final next = b.nextStop;
    final done = b.deliveredCount + b.failedCount;
    final total = b.items.length;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
      children: [
        _BackRow(
          onReport: () => showReportProblem(context, b.id),
          onRoute: b.allStopsDone ? null : () => openBatchRoute(context, b),
        ),
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
            b.allStopsDone
                ? const TagChip.success(label: 'All stops done')
                : const TagChip(label: 'Out for delivery', color: Colors.white, background: AppColors.warning),
          ],
        ),
        AppSpacing.gapMd,
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primaryDark),
                  const SizedBox(width: 6),
                  Text('$done/$total', style: AppTextStyles.h2),
                  const SizedBox(width: 4),
                  Text('parcels', style: AppTextStyles.caption),
                  const Spacer(),
                  if (b.codCollected > 0)
                    Text('${FormatUtils.peso(b.codCollected)} collected', style: AppTextStyles.caption),
                ],
              ),
              AppSpacing.gapSm,
              ClipRRect(
                borderRadius: AppRadius.pillAll,
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapLg,
        for (final stop in b.stops) ...[
          _StopTile(
            stop: stop,
            isNext: identical(stop, next),
            onItems: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => OrdersToCollectScreen(stop: stop))),
            onGo: stop.isDone ? null : () => _go(stop),
          ),
          AppSpacing.gapMd,
        ],
      ],
    );
  }

  Widget _routeButtons(RiderBatch b) {
    return ElevatedButton(
      onPressed: b.allStopsDone ? _returnToHub : null,
      style: _primary,
      child: Text(b.allStopsDone
          ? (b.dropOff?.arrivedAt != null ? 'Open handover' : 'Return to Hub')
          : 'Return to Hub (finish every stop first)'),
    );
  }

  static final _primary = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.border,
    disabledForegroundColor: AppColors.textMuted,
    elevation: 0,
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
  );

  static final _outlined = OutlinedButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    side: const BorderSide(color: AppColors.border),
    minimumSize: const Size.fromHeight(48),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
  );
}

class _BackRow extends StatelessWidget {
  const _BackRow({required this.onReport, this.onRoute});
  final VoidCallback onReport;
  final VoidCallback? onRoute;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          visualDensity: VisualDensity.compact,
        ),
        const Spacer(),
        if (onRoute != null)
          IconButton(
            tooltip: 'Full route in Maps',
            onPressed: onRoute,
            icon: const Icon(Icons.alt_route_rounded, color: AppColors.primaryDark),
          ),
        IconButton(
          tooltip: 'Report a problem',
          onPressed: onReport,
          icon: const Icon(Icons.flag_outlined, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Batch number, earnings, stops and parcels; [footer] under a divider.
class _BatchSummary extends StatelessWidget {
  const _BatchSummary({required this.batch, required this.footer});
  final RiderBatch batch;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BATCH NUMBER', style: AppTextStyles.overline),
                    Text('#${batch.batchNo}', style: AppTextStyles.h2.copyWith(fontSize: 20)),
                  ],
                ),
              ),
              if (batch.estEarnings > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('EST. EARNINGS', style: AppTextStyles.overline),
                    Text(FormatUtils.peso(batch.estEarnings),
                        style: AppTextStyles.h2.copyWith(fontSize: 20, color: AppColors.primaryDark)),
                  ],
                ),
            ],
          ),
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _Fact(icon: Icons.location_on_outlined, text: '${batch.stops.length} ${batch.stops.length == 1 ? 'Stop' : 'Stops'}'),
              _Fact(icon: Icons.inventory_2_outlined, text: '${batch.items.length} Parcels'),
              if (batch.codTotal > 0) _Fact(icon: Icons.payments_outlined, text: '${FormatUtils.peso(batch.codTotal)} COD'),
            ],
          ),
          AppSpacing.gapMd,
          const Divider(height: 1, color: AppColors.border),
          AppSpacing.gapMd,
          footer,
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodyStrong),
      ],
    );
  }
}

/// A parcel on the load-out list: who it goes to and whether it is scanned.
class _ParcelTile extends StatelessWidget {
  const _ParcelTile({required this.stop, required this.item});
  final BatchStop stop;
  final BatchItem item;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.mdAll),
            child: Icon(item.isReturn ? Icons.keyboard_return_rounded : Icons.inventory_2_rounded,
                size: 18, color: AppColors.primaryDark),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stop.name, style: AppTextStyles.bodyStrong),
                if (stop.address != null)
                  Text(stop.address!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
                Text([item.trackingNo, if (item.isReturn) 'return to seller'].join(' · '),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          itemStatusChip(item.status),
        ],
      ),
    );
  }
}

/// A stop on the route: who, where, and what is left to do there.
class _StopTile extends StatelessWidget {
  const _StopTile({required this.stop, required this.isNext, required this.onItems, required this.onGo});
  final BatchStop stop;
  final bool isNext;
  final VoidCallback onItems;
  final VoidCallback? onGo;

  @override
  Widget build(BuildContext context) {
    final refs = stop.items.map((i) => i.reference).join(', ');
    final doneAt = stop.items.map((i) => i.doneAt).whereType<DateTime>().fold<DateTime?>(null,
        (a, b) => a == null || b.isAfter(a) ? b : a);
    return Container(
      decoration: isNext
          ? BoxDecoration(borderRadius: AppRadius.lgAll, border: Border.all(color: AppColors.primary, width: 1.5))
          : null,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(stop.name, style: AppTextStyles.h2)),
                _statusChip(),
              ],
            ),
            Text(refs, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            if (doneAt != null && stop.isDone)
              Text(_when(context, doneAt), style: AppTextStyles.caption),
            if (stop.address != null) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(stop.address!, style: AppTextStyles.caption)),
                ],
              ),
            ],
            if (!stop.isDone && stop.codTotal > 0) ...[
              const SizedBox(height: 4),
              Text('Collect ${FormatUtils.peso(stop.codTotal)} (COD)',
                  style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
            ],
            if (stop.isDone && stop.items.any((i) => i.note != null)) ...[
              const SizedBox(height: 4),
              Text(stop.items.firstWhere((i) => i.note != null).note!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark)),
            ],
            AppSpacing.gapMd,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onItems,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                    ),
                    child: const Text('View items'),
                  ),
                ),
                if (onGo != null) ...[
                  AppSpacing.gapSm,
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onGo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isNext || stop.hasArrived ? AppColors.primary : AppColors.primarySoft,
                        foregroundColor: isNext || stop.hasArrived ? Colors.white : AppColors.primaryDark,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                      ),
                      child: Text(stop.hasArrived ? 'Scan & deliver' : 'Navigate'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip() => switch (stop.status) {
        'delivered' => const TagChip.success(label: 'Delivered'),
        'failed' => const TagChip(label: 'Failed'),
        'partial' => const TagChip.warning(label: 'Partly delivered'),
        _ => isNext
            ? const TagChip.warning(label: 'On-going')
            : const TagChip.muted(label: 'Pending'),
      };

  static String _when(BuildContext context, DateTime at) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[at.month - 1]} ${at.day}, ${at.year} · ${TimeOfDay.fromDateTime(at).format(context)}';
  }
}
