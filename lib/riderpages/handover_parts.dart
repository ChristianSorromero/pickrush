import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/surface_card.dart';

/// Pieces shared by the station handover checklists (pickup drop-off and the
/// delivery return): the header with the batch number to tell the staff and
/// overall progress, numbered steps, and the parcel list (waiting first).

class HandoverHeader extends StatelessWidget {
  const HandoverHeader({
    super.key,
    required this.batch,
    required this.done,
    required this.total,
    required this.complete,
  });

  final RiderBatch batch;
  final int done;
  final int total;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(complete ? 'Batch complete!' : 'Hand over at ${batch.dropOff?.name ?? 'the station'}',
            style: AppTextStyles.h1),
        AppSpacing.gapMd,
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (complete) ...[
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 32, color: AppColors.success),
                    AppSpacing.gapMd,
                    Expanded(child: Text('Everything is handed over.', style: AppTextStyles.h2)),
                  ],
                ),
                if (batch.estEarnings > 0) ...[
                  AppSpacing.gapSm,
                  Text('You earned ${FormatUtils.peso(batch.estEarnings)} on this batch',
                      style: AppTextStyles.bodyStrong.copyWith(color: AppColors.success)),
                ],
              ] else ...[
                Text('TELL THE STAFF YOUR BATCH', style: AppTextStyles.overline),
                Text('#${batch.batchNo}', style: AppTextStyles.display.copyWith(fontSize: 30)),
              ],
              if (total > 0) ...[
                AppSpacing.gapMd,
                ClipRRect(
                  borderRadius: AppRadius.pillAll,
                  child: LinearProgressIndicator(
                    value: done / total,
                    minHeight: 8,
                    color: complete ? AppColors.success : AppColors.primary,
                    backgroundColor: AppColors.border,
                  ),
                ),
                const SizedBox(height: 6),
                Text('$done of $total done', style: AppTextStyles.caption),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One numbered step of the checklist: a title, its status on the right, and
/// what belongs to it underneath.
class HandoverStep extends StatelessWidget {
  const HandoverStep({
    super.key,
    required this.number,
    required this.title,
    required this.done,
    required this.status,
    this.child,
  });

  final int? number;
  final String title;
  final bool done;
  final String status;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 28,
                width: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? AppColors.success : AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: done
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : Text(number?.toString() ?? '•',
                        style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primaryDark)),
              ),
              AppSpacing.gapMd,
              Expanded(child: Text(title, style: AppTextStyles.h2)),
              Text(status,
                  style: AppTextStyles.caption.copyWith(
                      color: done ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w700)),
            ],
          ),
          if (child != null) ...[
            AppSpacing.gapMd,
            child!,
          ],
        ],
      ),
    );
  }
}

/// Parcels to hand over: the ones the staff still have to scan on top, the
/// scanned ones folded away underneath.
class ParcelChecklist extends StatefulWidget {
  const ParcelChecklist({super.key, required this.items, required this.isDone});

  final List<BatchItem> items;
  final bool Function(BatchItem) isDone;

  @override
  State<ParcelChecklist> createState() => _ParcelChecklistState();
}

class _ParcelChecklistState extends State<ParcelChecklist> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final waiting = widget.items.where((i) => !widget.isDone(i)).toList();
    final done = widget.items.where(widget.isDone).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in waiting) _ParcelRow(item: item, done: false),
        if (done.isNotEmpty)
          InkWell(
            onTap: () => setState(() => _showDone = !_showDone),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.success),
                  AppSpacing.gapMd,
                  Expanded(child: Text('${done.length} received', style: AppTextStyles.bodyStrong)),
                  Icon(_showDone ? Icons.expand_less : Icons.expand_more, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        if (_showDone || waiting.isEmpty)
          for (final item in done) _ParcelRow(item: item, done: true),
      ],
    );
  }
}

class _ParcelRow extends StatelessWidget {
  const _ParcelRow({required this.item, required this.done});
  final BatchItem item;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(done ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
              size: 20, color: done ? AppColors.success : AppColors.textMuted),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.trackingNo, style: AppTextStyles.bodyStrong),
                if (item.orderNumber != null) Text('Order #${item.orderNumber}', style: AppTextStyles.caption),
                if (item.note != null) Text(item.note!, style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(done ? 'Received' : 'Waiting for scan',
              style: AppTextStyles.caption.copyWith(color: done ? AppColors.success : null)),
        ],
      ),
    );
  }
}

/// Under the checklist: that it updates by itself, or the way home.
class HandoverFooter extends StatelessWidget {
  const HandoverFooter({super.key, required this.complete});
  final bool complete;

  @override
  Widget build(BuildContext context) {
    if (complete) {
      return AppButton(
        label: 'Back to home',
        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          height: 12,
          width: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textMuted),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text('Updates by itself as the staff scan and record.',
              style: AppTextStyles.caption, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
