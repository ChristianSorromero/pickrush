import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/pickups/batch_routes.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

/// Pickups tab (or, with [type] delivery, the Deliveries tab): every open
/// batch of that kind, offers first.
class PickupsScreen extends StatefulWidget {
  const PickupsScreen({super.key, this.type = BatchType.pickup});

  final BatchType type;

  @override
  State<PickupsScreen> createState() => _PickupsScreenState();
}

class _PickupsScreenState extends State<PickupsScreen> {
  bool get _delivery => widget.type == BatchType.delivery;
  List<RiderBatch>? _batches;
  String? _error;
  int _seenChanges = -1;

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

  void _onWatcher() {
    if (assignmentWatcher.changes != _seenChanges) _load();
  }

  Future<void> _load() async {
    _seenChanges = assignmentWatcher.changes;
    try {
      final batches = (await riderTasks.batches()).where((b) => b.type == widget.type).toList();
      if (mounted) {
        setState(() {
          _batches = batches;
          _error = null;
        });
      }
    } on TaskException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _open(RiderBatch b) async {
    await openBatch(context, b);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final batches = _batches;
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
          children: [
            Text(_delivery ? 'Deliveries' : 'Pickups', style: AppTextStyles.h1),
            Text('Batches from your station', style: AppTextStyles.body),
            AppSpacing.gapXl,
            if (batches == null && _error == null)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (batches == null)
              _Message(icon: Icons.wifi_off_rounded, text: _error!)
            else if (batches.isEmpty)
              _Message(
                icon: Icons.inventory_2_outlined,
                text: 'No ${_delivery ? 'deliveries' : 'pickups'} right now.\nYou will be notified when your station assigns one.',
              )
            else
              for (final b in batches) ...[
                _BatchTile(batch: b, onTap: () => _open(b)),
                AppSpacing.gapMd,
              ],
          ],
        ),
      ),
    );
  }
}

String _progressLabel(RiderBatch b) {
  if (!b.isDelivery) return b.allPickedUp ? 'Bring to station' : 'In progress';
  if (!b.hasStarted) return 'Load at station';
  return b.allStopsDone ? 'Return to hub' : 'Out for delivery';
}

class _BatchTile extends StatelessWidget {
  const _BatchTile({required this.batch, required this.onTap});
  final RiderBatch batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final next = batch.nextStop;
    final progress = batch.isDelivery
        ? '${batch.deliveredCount + batch.failedCount}/${batch.parcelCount} parcels done'
            '${batch.codTotal > 0 ? ' · COD ${FormatUtils.peso(batch.codTotal)}' : ''}'
        : '${batch.pickedCount}/${batch.parcelCount} parcels collected';
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${batch.batchNo}', style: AppTextStyles.h2),
                const Spacer(),
                batch.isOffer
                    ? const TagChip.warning(label: 'New · Tap to review')
                    : TagChip.success(label: _progressLabel(batch)),
              ],
            ),
            AppSpacing.gapSm,
            Text(
              '${batch.stops.length} ${batch.stops.length == 1 ? 'stop' : 'stops'} · $progress',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            if (next != null) ...[
              AppSpacing.gapSm,
              Row(
                children: [
                  Icon(batch.isDelivery ? Icons.location_on_rounded : Icons.storefront_rounded,
                      size: 16, color: AppColors.primaryDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      batch.isOffer
                          ? batch.stops.map((s) => s.name).join(', ')
                          : batch.isDelivery && !batch.hasStarted
                              ? 'Scan the parcels at the station'
                              : 'Next: ${next.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          AppSpacing.gapMd,
          Text(text, textAlign: TextAlign.center, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
