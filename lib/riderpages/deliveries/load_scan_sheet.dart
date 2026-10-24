import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/services/scan_feedback.dart';
import 'package:rider_app/widgets/scan_camera.dart';

/// Loading at the station: scan each parcel of the batch onto the vehicle.
/// Every good scan beeps and is saved right away; a wrong one buzzes.
/// Returns the batch as it stands when the rider taps Done.
Future<RiderBatch?> showLoadScanSheet(BuildContext context, RiderBatch batch) {
  return showModalBottomSheet<RiderBatch>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (_) => _LoadSheet(batch: batch),
  );
}

class _LoadSheet extends StatefulWidget {
  const _LoadSheet({required this.batch});
  final RiderBatch batch;

  @override
  State<_LoadSheet> createState() => _LoadSheetState();
}

class _LoadSheetState extends State<_LoadSheet> {
  late RiderBatch _batch = widget.batch;
  bool _busy = false;
  String? _lastCode;
  DateTime _lastAt = DateTime(2000);
  BatchItem? _lastItem;
  BatchStop? _lastStop;
  String? _message;
  bool _messageIsError = false;

  int get _loaded => _batch.items.where((i) => i.isLoaded).length;
  int get _total => _batch.items.length;

  /// Returns null when the parcel was loaded, otherwise why not.
  Future<String?> _scan(String raw) async {
    final code = normalizeWaybill(raw);
    // The camera keeps seeing the label just scanned: ignore it for a moment.
    if (code == _lastCode && DateTime.now().difference(_lastAt) < const Duration(seconds: 3)) return null;
    if (_busy) return null;
    _lastCode = code;
    _lastAt = DateTime.now();

    BatchStop? stop;
    BatchItem? item;
    for (final s in _batch.stops) {
      for (final i in s.items) {
        if (normalizeWaybill(i.trackingNo) == code) {
          stop = s;
          item = i;
        }
      }
    }
    if (item == null) return _refuse('$code is not part of this batch.');
    if (item.isLoaded) {
      setState(() => _say('$code is already scanned.', error: false));
      return null;
    }

    setState(() => _busy = true);
    try {
      final batch = await riderTasks.load(_batch.id, code);
      ScanFeedback.success();
      if (!mounted) return null;
      setState(() {
        _batch = batch;
        _lastStop = stop;
        _lastItem = item;
        _say(_loaded == _total ? 'All parcels scanned. Tap Done, then Start Route.' : null, error: false);
      });
      return null;
    } on TaskException catch (e) {
      return _refuse(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _refuse(String message) {
    ScanFeedback.error();
    if (mounted) setState(() => _say(message, error: true));
    return message;
  }

  void _say(String? message, {required bool error}) {
    _message = message;
    _messageIsError = error;
  }

  @override
  Widget build(BuildContext context) {
    final left = _total - _loaded;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: AppRadius.pillAll),
              ),
            ),
            AppSpacing.gapMd,
            Row(
              children: [
                Text('Scan parcel', style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary, fontSize: 18)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(_batch),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.pillAll),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 8, width: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('$_loaded of $_total scanned',
                      style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            AppSpacing.gapMd,
            ScanCamera(onCode: _scan, height: 230),
            AppSpacing.gapSm,
            Center(
              child: Text('Point the camera at the parcel barcode',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ),
            if (_message != null) ...[
              AppSpacing.gapSm,
              Text(_message!,
                  style: AppTextStyles.bodyStrong.copyWith(
                      color: _messageIsError ? AppColors.primary : AppColors.success)),
            ],
            if (_lastItem != null) ...[
              AppSpacing.gapMd,
              Text('LAST SCANNED', style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary)),
              AppSpacing.gapSm,
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.mdAll, border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success),
                    AppSpacing.gapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_lastStop!.name, style: AppTextStyles.bodyStrong),
                          Text([_lastItem!.trackingNo, if (_lastStop!.address != null) _lastStop!.address!].join(' · '),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    Text('SCANNED', style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
            AppSpacing.gapSm,
            Center(
              child: TextButton(
                onPressed: () => showManualEntry(context, _scan),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
                child: const Text("Can't scan? Enter code manually"),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_batch),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
              ),
              child: const Text('Done'),
            ),
            AppSpacing.gapSm,
            Center(
              child: Text(left == 0 ? 'Every parcel is scanned' : '$left ${left == 1 ? 'parcel' : 'parcels'} left to scan',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
