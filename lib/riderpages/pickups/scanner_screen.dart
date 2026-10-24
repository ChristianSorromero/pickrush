import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/pickups/hub_handover_screen.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/services/scan_feedback.dart';
import 'package:rider_app/widgets/scan_camera.dart';
import 'package:rider_app/widgets/slide_to_accept.dart';
import 'package:rider_app/widgets/surface_card.dart';

/// At the seller: scan the waybill (barcode or QR) on every parcel, then
/// confirm. Parcels the seller cannot hand over get a reason and go back to
/// the station. Confirming moves each order to "picked up" for the station,
/// the seller and the buyer.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.batch, required this.stopNumber});

  final RiderBatch batch;
  final int stopNumber;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _Scan {
  const _Scan(this.trackingNo, this.at);
  final String trackingNo;
  final DateTime at;
}

class _ScannerScreenState extends State<ScannerScreen> {
  final List<_Scan> _scans = [];

  // One key for every retry from this screen, so a resend is not counted twice.
  late final String _requestKey =
      'b${widget.batch.id}-s${widget.stopNumber}-${DateTime.now().microsecondsSinceEpoch}';

  String? _lastRejected;

  BatchStop get _stop =>
      widget.batch.stops.firstWhere((s) => s.number == widget.stopNumber);

  /// Tracking numbers still to collect here.
  late final Set<String> _expected = {for (final i in _stop.toPick) normalizeWaybill(i.trackingNo)};

  /// Returns null when accepted, otherwise why not.
  String? _accept(String raw) {
    final no = normalizeWaybill(raw);
    if (_scans.any((s) => s.trackingNo == no)) return '$no is already scanned.';
    if (_expected.contains(no)) {
      ScanFeedback.success();
      setState(() => _scans.insert(0, _Scan(no, DateTime.now())));
      return null;
    }

    final elsewhere = widget.batch.stops
        .where((s) => s.number != widget.stopNumber && s.items.any((i) => normalizeWaybill(i.trackingNo) == no))
        .firstOrNull;
    final message = elsewhere != null
        ? '$no belongs to ${elsewhere.sellerName} (Stop ${elsewhere.number}), not this stop.'
        : '$no is not part of this batch. Check the waybill.';
    if (_lastRejected != no) {
      _lastRejected = no;
      ScanFeedback.error();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.primaryDark));
    }
    return message;
  }

  Future<void> _enterManually() => showManualEntry(context, (code) async => _accept(code));

  Future<void> _confirm() async {
    final missing = _expected.where((no) => !_scans.any((s) => s.trackingNo == no)).toList();
    var notCollected = const <NotCollected>[];
    if (missing.isNotEmpty) {
      final why = await _askWhyMissing(missing);
      if (why == null) throw StateError('cancelled'); // resets the slider
      notCollected = [for (final no in missing) NotCollected(no, why.$1, why.$2)];
    }
    try {
      final batch = await riderTasks.confirmPickup(
        widget.batch.id,
        trackingNos: [for (final s in _scans) s.trackingNo],
        notCollected: notCollected,
        requestKey: _requestKey,
      );
      assignmentWatcher.poll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_scans.isEmpty
            ? 'Stop closed. The station will follow up with ${_stop.sellerName}.'
            : 'Pickup at ${_stop.sellerName} confirmed (${_scans.length}).'),
      ));
      if (batch.allPickedUp) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HubHandoverScreen(batch: batch)));
      } else {
        Navigator.of(context).pop(batch);
      }
    } on TaskException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      rethrow;
    }
  }

  /// (reason key, note) for the parcels not scanned, or null to keep scanning.
  Future<(String, String?)?> _askWhyMissing(List<String> missing) async {
    final options = await riderTasks.options().catchError((_) => const RiderOptions(
        pickupFailureReasons: [Choice('other', 'Other')], riderProblems: []));
    if (!mounted) return null;
    return showModalBottomSheet<(String, String?)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => _MissingSheet(missing: missing, reasons: options.pickupFailureReasons),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _expected.length;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
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
            Text('Stop ${_stop.number} · ${_stop.sellerName}', style: AppTextStyles.body),
            AppSpacing.gapLg,
            ScanCamera(onCode: _accept),
            AppSpacing.gapMd,
            Text('Align the barcode or QR code within the frame',
                textAlign: TextAlign.center, style: AppTextStyles.body),
            AppSpacing.gapMd,
            OutlinedButton.icon(
              onPressed: _enterManually,
              icon: const Icon(Icons.keyboard_outlined),
              label: const Text('ENTER ID MANUALLY'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.textPrimary, width: 1.5),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                textStyle: AppTextStyles.button,
              ),
            ),
            AppSpacing.gapLg,
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('SCANNED PARCELS', style: AppTextStyles.overline),
                      const Spacer(),
                      Text('${_scans.length}/$total', style: AppTextStyles.h2),
                    ],
                  ),
                  AppSpacing.gapMd,
                  if (_scans.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: Text('No parcels scanned at this stop yet',
                          textAlign: TextAlign.center, style: AppTextStyles.caption),
                    )
                  else
                    for (final s in _scans) _ScannedRow(scan: s),
                ],
              ),
            ),
            AppSpacing.gapXl,
            SlideToAccept(
              label: _scans.length == total
                  ? 'Confirm Pickup'
                  : _scans.isEmpty
                      ? 'Nothing to collect'
                      : 'Confirm ${_scans.length} of $total',
              onSubmit: _confirm,
            ),
            AppSpacing.gapSm,
            if (_scans.length < total)
              Text(
                'Parcels you don\'t scan go back to the station with a reason.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
          ],
        ),
      ),
    );
  }
}

class _ScannedRow extends StatelessWidget {
  const _ScannedRow({required this.scan});
  final _Scan scan;

  @override
  Widget build(BuildContext context) {
    final t = TimeOfDay.fromDateTime(scan.at).format(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success),
          AppSpacing.gapMd,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('#${scan.trackingNo}', style: AppTextStyles.bodyStrong),
              Text('Scanned at $t', style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _MissingSheet extends StatefulWidget {
  const _MissingSheet({required this.missing, required this.reasons});
  final List<String> missing;
  final List<Choice> reasons;

  @override
  State<_MissingSheet> createState() => _MissingSheetState();
}

class _MissingSheetState extends State<_MissingSheet> {
  String? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.missing.length;
    final ready = _reason != null && (_reason != 'other' || _note.text.trim().isNotEmpty);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$n ${n == 1 ? 'parcel' : 'parcels'} not scanned',
                  style: AppTextStyles.h2.copyWith(fontSize: 18)),
              const SizedBox(height: 2),
              Text(widget.missing.join(', '), style: AppTextStyles.caption),
              AppSpacing.gapSm,
              Text('Why couldn\'t you collect ${n == 1 ? 'it' : 'them'}? The station will reassign ${n == 1 ? 'it' : 'them'}.',
                  style: AppTextStyles.body),
              AppSpacing.gapMd,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final r in widget.reasons)
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
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Keep scanning'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: ready
                          ? () => Navigator.pop(context, (_reason!, _note.text.trim()))
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
