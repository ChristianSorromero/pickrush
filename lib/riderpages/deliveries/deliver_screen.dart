import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/pickups/trip_screen.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/services/scan_feedback.dart';
import 'package:rider_app/widgets/scan_camera.dart';
import 'package:rider_app/widgets/slide_to_accept.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

/// At the door: scan the parcel (it must be one for this stop), see what to
/// collect, take a proof-of-delivery photo, then Confirm Delivery. Moves the
/// order to "delivered" for the station, the seller and the buyer.
/// "Can't deliver" records a failed attempt (reason + photo) instead.
class DeliverScreen extends StatefulWidget {
  const DeliverScreen({super.key, required this.batch, required this.stopNumber});

  final RiderBatch batch;
  final int stopNumber;

  @override
  State<DeliverScreen> createState() => _DeliverScreenState();
}

class _DeliverScreenState extends State<DeliverScreen> {
  final Map<String, DateTime> _scanned = {};
  String? _photoPath;
  String? _lastRejected;

  // One key per screen, so a retried confirm is not recorded twice.
  late final String _requestKey =
      'b${widget.batch.id}-d${widget.stopNumber}-${DateTime.now().microsecondsSinceEpoch}';

  BatchStop get _stop => widget.batch.stops.firstWhere((s) => s.number == widget.stopNumber);
  List<BatchItem> get _toDeliver => _stop.toDeliver;
  List<BatchItem> get _scannedItems =>
      _toDeliver.where((i) => _scanned.containsKey(normalizeWaybill(i.trackingNo))).toList();
  double get _codDue => _scannedItems.fold(0, (sum, i) => sum + i.codAmount);

  /// Returns null when accepted, otherwise why not.
  String? _accept(String raw) {
    final code = normalizeWaybill(raw);
    if (_scanned.containsKey(code)) return null;
    final mine = _toDeliver.any((i) => normalizeWaybill(i.trackingNo) == code);
    if (mine) {
      ScanFeedback.success();
      setState(() => _scanned[code] = DateTime.now());
      return null;
    }
    final elsewhere = widget.batch.stops
        .where((s) => s.number != widget.stopNumber && s.items.any((i) => normalizeWaybill(i.trackingNo) == code))
        .firstOrNull;
    final message = elsewhere != null
        ? 'Wrong parcel: $code is for ${elsewhere.name} (stop ${elsewhere.number}).'
        : '$code is not part of this batch. Check the waybill.';
    if (_lastRejected != code) {
      _lastRejected = code;
      ScanFeedback.error();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.primaryDark));
    }
    return message;
  }

  Future<String?> _takePhoto() async {
    try {
      final shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
      return shot?.path;
    } catch (_) {
      _toast('Could not open the camera for the photo.');
      return null;
    }
  }

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirm() async {
    var batch = widget.batch;
    try {
      for (final item in _scannedItems) {
        batch = await riderTasks.deliver(widget.batch.id, item.assignmentId,
            trackingNo: item.trackingNo, codConfirmed: item.codAmount, photoPath: _photoPath!, requestKey: _requestKey);
      }
    } on TaskException catch (e) {
      ScanFeedback.error();
      _toast(e.message);
      rethrow; // resets the slider
    }
    assignmentWatcher.poll();
    if (!mounted) return;
    _toast(_codDue > 0
        ? 'Delivered. ${FormatUtils.peso(_codDue)} collected.'
        : 'Delivered.');
    _finish(batch);
  }

  void _finish(RiderBatch batch) {
    if (batch.allStopsDone) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => TripScreen(batch: batch)));
    } else {
      Navigator.of(context).pop(batch);
    }
  }

  Future<void> _cantDeliver() async {
    // Every parcel still to deliver here (returns to a seller cannot fail from the app).
    final targets = _toDeliver.where((i) => !i.isReturn).toList();
    if (targets.isEmpty) {
      _toast('A return to the seller cannot be marked failed here. Report a problem to your station.');
      return;
    }
    final batch = await showModalBottomSheet<RiderBatch>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => _FailSheet(batchId: widget.batch.id, items: targets, requestKey: _requestKey, takePhoto: _takePhoto),
    );
    if (batch == null || !mounted) return;
    assignmentWatcher.poll();
    _toast('Failed delivery recorded. Bring the parcel back to the station.');
    _finish(batch);
  }

  @override
  Widget build(BuildContext context) {
    final total = _toDeliver.length;
    final ready = _scannedItems.isNotEmpty && _photoPath != null;
    return Scaffold(
      body: SafeArea(
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
            Text('Parcel Scanner', style: AppTextStyles.h1),
            Text('Stop ${_stop.number} · ${_stop.name}', style: AppTextStyles.body),
            AppSpacing.gapLg,
            ScanCamera(onCode: _accept),
            AppSpacing.gapMd,
            Text('Align the barcode or QR code within the frame',
                textAlign: TextAlign.center, style: AppTextStyles.body),
            AppSpacing.gapSm,
            TextButton.icon(
              onPressed: () => showManualEntry(context, (code) async => _accept(code)),
              icon: const Icon(Icons.keyboard_outlined, size: 18),
              label: const Text('Enter ID manually'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
            ),
            AppSpacing.gapMd,
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('PARCEL DETAILS', style: AppTextStyles.overline),
                      const Spacer(),
                      Text('${_scannedItems.length}/$total', style: AppTextStyles.h2),
                    ],
                  ),
                  AppSpacing.gapMd,
                  for (final item in _toDeliver) _ParcelRow(item: item, scannedAt: _scanned[normalizeWaybill(item.trackingNo)]),
                  if (_toDeliver.isEmpty)
                    Text('Nothing left to deliver at this stop.', style: AppTextStyles.caption),
                  if (_scannedItems.isNotEmpty) ...[
                    const Divider(height: AppSpacing.xl, color: AppColors.border),
                    _Line(label: 'Price', value: FormatUtils.peso(_scannedItems.fold(0.0, (s, i) => s + i.codAmount))),
                    _Line(
                      label: 'Mode of Payment',
                      value: _scannedItems.every((i) => i.isReturn)
                          ? 'Return to seller (no cash)'
                          : _codDue > 0 ? 'Cash on Delivery' : 'Already paid',
                    ),
                    if (_codDue > 0) ...[
                      AppSpacing.gapSm,
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: AppRadius.mdAll),
                        child: Text('Collect exactly ${FormatUtils.peso(_codDue)} in cash before handing over.',
                            style: AppTextStyles.bodyStrong.copyWith(color: AppColors.warning)),
                      ),
                    ],
                    AppSpacing.gapLg,
                    Text('PROOF OF DELIVERY', style: AppTextStyles.overline),
                    AppSpacing.gapSm,
                    _PhotoTile(
                      path: _photoPath,
                      onTap: () async {
                        final path = await _takePhoto();
                        if (path != null && mounted) setState(() => _photoPath = path);
                      },
                    ),
                  ],
                ],
              ),
            ),
            AppSpacing.gapXl,
            SlideToAccept(
              label: _scannedItems.length < total && _scannedItems.isNotEmpty
                  ? 'Confirm Delivery (${_scannedItems.length} of $total)'
                  : 'Confirm Delivery',
              enabled: ready,
              onSubmit: _confirm,
            ),
            AppSpacing.gapSm,
            Text(
              _scannedItems.isEmpty
                  ? 'Scan the parcel to see the amount to collect.'
                  : _photoPath == null
                      ? 'Take a photo of the parcel with the recipient.'
                      : 'Slide when the parcel is handed over${_codDue > 0 ? ' and paid' : ''}.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            AppSpacing.gapMd,
            Center(
              child: TextButton.icon(
                onPressed: _toDeliver.isEmpty ? null : _cantDeliver,
                icon: const Icon(Icons.do_not_disturb_alt_rounded, size: 18),
                label: const Text("Can't deliver"),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParcelRow extends StatelessWidget {
  const _ParcelRow({required this.item, this.scannedAt});
  final BatchItem item;
  final DateTime? scannedAt;

  @override
  Widget build(BuildContext context) {
    final scanned = scannedAt != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(scanned ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: scanned ? AppColors.success : AppColors.textMuted),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.reference, style: AppTextStyles.bodyStrong),
                Text(
                  scanned
                      ? '${item.trackingNo} · scanned ${TimeOfDay.fromDateTime(scannedAt!).format(context)}'
                      : '${item.trackingNo}${item.description != null ? ' · ${item.description}' : ''}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          scanned
              ? const TagChip.success(label: 'Scanned')
              : const TagChip.muted(label: 'Scan'),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.body),
          const Spacer(),
          Text(value, style: AppTextStyles.bodyStrong),
        ],
      ),
    );
  }
}

/// "Tap to capture photo", then the photo with a retake overlay.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path, required this.onTap});
  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: path == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_camera_outlined, size: 32, color: AppColors.textMuted),
                  const SizedBox(height: 6),
                  Text('Tap to capture photo', style: AppTextStyles.caption),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(path!), fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: AppRadius.pillAll),
                      child: Text('Retake', style: AppTextStyles.caption.copyWith(color: Colors.white)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// "Can't deliver": a reason from the station's list, a note, and a photo of
/// the place. Applies to every parcel still to deliver at this stop.
class _FailSheet extends StatefulWidget {
  const _FailSheet({required this.batchId, required this.items, required this.requestKey, required this.takePhoto});
  final int batchId;
  final List<BatchItem> items;
  final String requestKey;
  final Future<String?> Function() takePhoto;

  @override
  State<_FailSheet> createState() => _FailSheetState();
}

class _FailSheetState extends State<_FailSheet> {
  List<Choice>? _reasons;
  String? _reason;
  String? _photo;
  final _note = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    riderTasks.options().then((o) {
      if (mounted) setState(() => _reasons = o.deliveryFailureReasons);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      RiderBatch? batch;
      for (final item in widget.items) {
        batch = await riderTasks.failDelivery(widget.batchId, item.assignmentId,
            reason: _reason!, note: _note.text.trim(), photoPath: _photo!, requestKey: widget.requestKey);
      }
      if (mounted) Navigator.of(context).pop(batch);
    } on TaskException catch (e) {
      ScanFeedback.error();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    final ready = _reason != null && _photo != null && (_reason != 'other' || _note.text.trim().isNotEmpty);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Can't deliver", style: AppTextStyles.h2.copyWith(fontSize: 18)),
              const SizedBox(height: 2),
              Text('$n ${n == 1 ? 'parcel' : 'parcels'} will be marked as a failed attempt. Bring ${n == 1 ? 'it' : 'them'} back to the station.',
                  style: AppTextStyles.caption),
              AppSpacing.gapLg,
              if (_reasons == null && _error == null)
                const Center(child: CircularProgressIndicator(color: AppColors.primary))
              else if (_reasons != null)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final r in _reasons!)
                      ChoiceChip(
                        label: Text(r.label),
                        selected: _reason == r.key,
                        onSelected: (on) => setState(() => _reason = on ? r.key : null),
                        selectedColor: AppColors.primarySoft,
                      ),
                  ],
                ),
              AppSpacing.gapMd,
              TextField(
                controller: _note,
                maxLength: 255,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _reason == 'other' ? 'What happened? (required)' : 'Note (optional)',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                ),
              ),
              Text('PHOTO OF THE PLACE', style: AppTextStyles.overline),
              AppSpacing.gapSm,
              _PhotoTile(
                path: _photo,
                onTap: () async {
                  final path = await widget.takePhoto();
                  if (path != null && mounted) setState(() => _photo = path);
                },
              ),
              if (_error != null) ...[
                AppSpacing.gapSm,
                Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark)),
              ],
              AppSpacing.gapMd,
              ElevatedButton(
                onPressed: ready && !_sending ? _send : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
                ),
                child: _sending
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Record failed delivery'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
