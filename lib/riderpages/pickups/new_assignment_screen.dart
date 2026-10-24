import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/pickups/batch_routes.dart';
import 'package:rider_app/riderpages/pickups/orders_to_collect_screen.dart';
import 'package:rider_app/riderpages/pickups/stop_card.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/launcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/slide_to_accept.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

/// A batch the station just offered: every stop (pickup sellers, or delivery
/// recipients with what each pays the rider) and where the batch ends, then
/// Slide to Accept or Decline.
class NewAssignmentScreen extends StatefulWidget {
  const NewAssignmentScreen({super.key, required this.batchId, this.initial});

  final int batchId;
  final RiderBatch? initial;

  @override
  State<NewAssignmentScreen> createState() => _NewAssignmentScreenState();
}

class _NewAssignmentScreenState extends State<NewAssignmentScreen> {
  late RiderBatch? _batch = widget.initial;
  String? _error;

  /// Long batches show the first stops and a "+N more stops" toggle.
  bool _showAllStops = false;
  static const _previewStops = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final batch = await riderTasks.batch(widget.batchId);
      if (!mounted) return;
      if (batch.status == BatchStatus.accepted) {
        // Accepted on another screen meanwhile: go straight to the batch.
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => acceptedBatchScreen(batch)));
        return;
      }
      setState(() {
        _batch = batch;
        _error = null;
      });
    } on TaskException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _accept() async {
    try {
      final batch = await riderTasks.accept(widget.batchId);
      assignmentWatcher.poll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(batch.isDelivery
              ? 'Batch accepted. Scan the parcels onto your vehicle at the station.'
              : 'Batch accepted. Head to the first stop.')));
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => acceptedBatchScreen(batch)));
    } on TaskException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
        _load();
      }
      rethrow; // resets the slider
    }
  }

  Future<void> _decline() async {
    final reason = await showDeclineDialog(context);
    if (reason == null || !mounted) return;
    try {
      await riderTasks.decline(widget.batchId, reason: reason);
      assignmentWatcher.poll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Batch declined. The station will reassign it.')));
      Navigator.of(context).pop();
    } on TaskException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _batch;
    return Scaffold(
      body: SafeArea(
        child: b == null
            ? _Loading(error: _error, onRetry: _load)
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
                  children: [
                    _Header(
                      delivery: b.isDelivery,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    AppSpacing.gapXl,
                    _Summary(batch: b),
                    AppSpacing.gapXl,
                    for (final stop in _visibleStops(b)) ...[
                      StopCard(
                        stop: stop,
                        tag: TagChip(
                            label: b.isDelivery
                                ? '${stop.isReturn ? 'Return' : 'Delivery'} ${stop.number}'
                                : 'Pickup ${stop.number}'),
                        status: b.isDelivery && stop.earnings > 0
                            ? Text(FormatUtils.peso(stop.earnings),
                                style: AppTextStyles.bodyStrong
                                    .copyWith(color: AppColors.primaryDark))
                            : null,
                        actions: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => OrdersToCollectScreen(stop: stop))),
                            icon: const Icon(Icons.list_alt_rounded, size: 16),
                            label: const Text('View items'),
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryDark,
                                padding: EdgeInsets.zero),
                          ),
                        ),
                      ),
                      AppSpacing.gapMd,
                    ],
                    if (b.stops.length > _previewStops + 1) ...[
                      _MoreStops(
                        hidden: b.stops.length - _previewStops,
                        expanded: _showAllStops,
                        onTap: () => setState(() => _showAllStops = !_showAllStops),
                      ),
                      AppSpacing.gapMd,
                    ],
                    if (b.dropOff != null)
                      DropOffCard(
                        dropOff: b.dropOff!,
                        label: b.isDelivery ? 'Remittance' : 'Drop-off',
                        trailing: b.isDelivery ? 'End route' : null,
                        note: b.isDelivery
                            ? 'Return here with the COD cash and any parcel not delivered'
                            : null,
                      ),
                    AppSpacing.gapMd,
                    OutlinedButton.icon(
                      onPressed: () => openBatchRoute(context, b),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Preview route in Maps'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.mdAll),
                      ),
                    ),
                    AppSpacing.gapXxl,
                    if (b.isOffer) ...[
                      SlideToAccept(onSubmit: _accept),
                      AppSpacing.gapMd,
                      AppButton(
                        label: 'Decline',
                        variant: AppButtonVariant.outline,
                        onPressed: _decline,
                      ),
                    ] else
                      _Closed(status: b.status),
                    AppSpacing.gapLg,
                  ],
                ),
              ),
      ),
    );
  }

  List<BatchStop> _visibleStops(RiderBatch b) =>
      _showAllStops || b.stops.length <= _previewStops + 1
          ? b.stops
          : b.stops.take(_previewStops).toList();
}

/// "+ 7 more stops ⌄" / "Show fewer stops ⌃".
class _MoreStops extends StatelessWidget {
  const _MoreStops({required this.hidden, required this.expanded, required this.onTap});
  final int hidden;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Text(expanded ? 'Show fewer stops' : '+ $hidden more stops',
                style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primaryDark)),
            const Spacer(),
            Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: AppColors.primaryDark),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, this.delivery = false});
  final VoidCallback onBack;
  final bool delivery;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          visualDensity: VisualDensity.compact,
        ),
        AppSpacing.gapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New Assignment', style: AppTextStyles.h1),
              Text(delivery
                      ? 'Review the delivery details before accepting'
                      : 'Review the details before accepting',
                  style: AppTextStyles.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.batch});
  final RiderBatch batch;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BATCH NUMBER', style: AppTextStyles.overline),
                    const SizedBox(height: 2),
                    Text('#${batch.batchNo}',
                        style: AppTextStyles.h2.copyWith(fontSize: 20)),
                  ],
                ),
              ),
              if (batch.estEarnings > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('EST. EARNINGS', style: AppTextStyles.overline),
                    const SizedBox(height: 2),
                    Text(FormatUtils.peso(batch.estEarnings),
                        style: AppTextStyles.h2.copyWith(
                            fontSize: 20, color: AppColors.primaryDark)),
                  ],
                ),
            ],
          ),
          AppSpacing.gapMd,
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${batch.stops.length} ${batch.stops.length == 1 ? 'Stop' : 'Stops'}',
                  style: AppTextStyles.bodyStrong),
              AppSpacing.gapXl,
              const Icon(Icons.inventory_2_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${batch.parcelCount} ${batch.parcelCount == 1 ? 'Parcel' : 'Parcels'}',
                  style: AppTextStyles.bodyStrong),
            ],
          ),
          if (batch.isDelivery && batch.codTotal > 0) ...[
            AppSpacing.gapSm,
            Row(
              children: [
                const Icon(Icons.payments_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${FormatUtils.peso(batch.codTotal)} COD to collect and remit',
                    style: AppTextStyles.bodyStrong),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The station where the batch ends.
class DropOffCard extends StatelessWidget {
  const DropOffCard({
    super.key,
    required this.dropOff,
    this.actions,
    this.label = 'Drop-off',
    this.trailing,
    this.note,
  });

  final DropOff dropOff;
  final Widget? actions;

  /// The chip: DROP-OFF (pickup) or REMITTANCE (delivery).
  final String label;

  /// e.g. "End route", top right.
  final String? trailing;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TagChip.muted(label: label),
              const Spacer(),
              if (trailing != null) Text(trailing!, style: AppTextStyles.caption),
            ],
          ),
          AppSpacing.gapSm,
          Text(dropOff.name, style: AppTextStyles.h2),
          if (dropOff.address != null && dropOff.address!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(dropOff.address!, style: AppTextStyles.caption),
          ],
          AppSpacing.gapSm,
          Row(
            children: [
              const Icon(Icons.badge_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(note ?? 'Hand the parcels to the station staff',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ),
            ],
          ),
          if (actions != null) ...[AppSpacing.gapMd, actions!],
        ],
      ),
    );
  }
}

class _Closed extends StatelessWidget {
  const _Closed({required this.status});
  final BatchStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      BatchStatus.declined => 'You declined this batch.',
      BatchStatus.cancelled => 'The station took this batch back.',
      BatchStatus.completed => 'This batch is finished.',
      _ => 'This batch is no longer waiting for you.',
    };
    return SurfaceCard(
      child: Text(text,
          textAlign: TextAlign.center, style: AppTextStyles.bodyStrong),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.error, required this.onRetry});
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, textAlign: TextAlign.center, style: AppTextStyles.body),
            AppSpacing.gapLg,
            AppButton(label: 'Try again', onPressed: onRetry, expand: false),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}

/// Asks why the rider declines. Returns null when they change their mind,
/// '' when they skip the reason.
Future<String?> showDeclineDialog(BuildContext context) {
  const reasons = [
    'Too far from my location',
    'Vehicle problem',
    'Too many parcels for my vehicle',
    'Ending my shift',
  ];
  String? picked;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Decline this batch?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The station will give it to another rider. Why are you declining?',
                style: AppTextStyles.body),
            AppSpacing.gapMd,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final r in reasons)
                  ChoiceChip(
                    label: Text(r),
                    selected: picked == r,
                    onSelected: (on) => setState(() => picked = on ? r : null),
                    selectedColor: AppColors.primarySoft,
                    labelStyle: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(picked ?? ''),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
            child: const Text('Decline'),
          ),
        ],
      ),
    ),
  );
}

/// Every stop not yet collected, in order, ending at the station.
void openBatchRoute(BuildContext context, RiderBatch b) async {
  final stops = [
    for (final s in b.stops)
      if (!s.isPickedUp && s.address != null) s.address!,
  ];
  final destination = b.dropOff == null
      ? null
      : [b.dropOff!.name, b.dropOff!.address].whereType<String>().join(', ');
  final ok = destination == null
      ? (stops.isNotEmpty && await Launcher.navigateTo(stops.first))
      : await Launcher.route(stops, destination);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Could not open Maps.')));
  }
}
