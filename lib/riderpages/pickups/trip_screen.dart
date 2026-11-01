import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/deliveries/deliver_screen.dart';
import 'package:rider_app/riderpages/deliveries/return_handover_screen.dart';
import 'package:rider_app/riderpages/pickups/handover_screen.dart';
import 'package:rider_app/riderpages/pickups/report_problem_sheet.dart';
import 'package:rider_app/riderpages/pickups/scanner_screen.dart';
import 'package:rider_app/services/launcher.dart';
import 'package:rider_app/services/location_service.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/slide_to_accept.dart';

/// Every stop is done: the trip to the station, or its handover checklist
/// when the rider already slid "Arrived at Hub".
Widget stationScreen(RiderBatch batch) {
  if (batch.dropOff?.arrivedAt == null) return TripScreen(batch: batch);
  return batch.isDelivery ? ReturnHandoverScreen(batch: batch) : HandoverScreen(batch: batch);
}

/// On the way to a stop ([stopNumber]) or, without one, to the station.
///
/// Destination first: where to go and what to do there, one button that opens
/// turn-by-turn in Google Maps, call / text, and the "Arrived" slider pinned
/// to the bottom so it never needs scrolling. The slider only locks to the pin
/// when the server enforces the arrival radius; otherwise the distance is just
/// recorded.
class TripScreen extends StatefulWidget {
  const TripScreen({super.key, required this.batch, this.stopNumber});

  final RiderBatch batch;

  /// The stop to go to; null means the station (drop-off).
  final int? stopNumber;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  StreamSubscription<GpsFix>? _gps;
  GpsFix? _fix;
  LocationProblem? _gpsProblem;

  RiderBatch get b => widget.batch;
  BatchStop? get _stop => widget.stopNumber == null
      ? null
      : b.stops.firstWhere((s) => s.number == widget.stopNumber);
  bool get _toHub => widget.stopNumber == null;

  Pin? get _pin => _toHub ? b.dropOff?.pin : _stop?.pin;
  bool get _delivery => b.isDelivery;
  String get _name => _toHub ? (b.dropOff?.name ?? 'Station') : _stop!.name;
  String? get _address => _toHub ? b.dropOff?.address : _stop?.address;
  String? get _phone => _toHub ? b.dropOff?.manager?.mobile : _stop?.mobile;
  bool get _alreadyArrived => _toHub ? b.dropOff?.arrivedAt != null : _stop!.hasArrived;

  /// Who the call / text goes to.
  String get _contact => _toHub
      ? 'hub manager'
      : switch (_stop!.kind) {
          'delivery' => 'buyer',
          _ => 'seller',
        };

  double? get _metres =>
      _fix != null && _pin != null ? LocationService.metres(_fix!, _pin!) : null;

  /// Far from a pinned stop (only a warning unless the radius is enforced).
  bool get _far {
    final m = _metres;
    return m != null && m > b.arrivalRadiusM + math.min(_fix!.accuracy, 50);
  }

  /// Allowed to slide "Arrived" (the server checks again).
  bool get _unlocked {
    if (!b.arrivalLocked) return true; // GPS is read when sliding
    if (_fix == null) return false;
    if (_pin == null) return true; // no pin: recorded, not checked
    return _metres! <= b.arrivalRadiusM + math.min(_fix!.accuracy, 50);
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _gps?.cancel();
    super.dispose();
  }

  void _listen() {
    _gps?.cancel();
    setState(() => _gpsProblem = null);
    _gps = locationService.watch().listen(
      (fix) => setState(() => _fix = fix),
      onError: (Object e) => setState(() => _gpsProblem =
          e is LocationProblem ? e : LocationProblem('Could not read your location.')),
    );
  }

  Future<void> _openMaps() async {
    final ok = await Launcher.navigate(
        pin: _pin, fallback: [_name, _address].whereType<String>().join(', '));
    if (!ok && mounted) _toast('Could not open Google Maps.');
  }

  Future<void> _fixGps() async {
    if (_gpsProblem?.openSettings ?? false) await locationService.openSettings();
    _listen();
  }

  Future<void> _arrive() async {
    try {
      final fix = _fix ?? await locationService.current();
      final batch = _toHub
          ? await riderTasks.arriveAtHub(b.id, fix)
          : await riderTasks.arriveAtStop(b.id, [for (final i in _stop!.open) i.assignmentId], fix);
      if (!mounted) return;
      _next(batch);
    } on TaskException catch (e) {
      _toast(e.message);
      rethrow;
    } on LocationProblem catch (e) {
      _toast(e.message);
      rethrow;
    }
  }

  void _next(RiderBatch batch) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => _toHub
          ? (_delivery ? ReturnHandoverScreen(batch: batch) : HandoverScreen(batch: batch))
          : (_delivery
              ? DeliverScreen(batch: batch, stopNumber: widget.stopNumber!)
              : ScannerScreen(batch: batch, stopNumber: widget.stopNumber!)),
    ));
  }

  void _text() {
    final stop = _stop;
    Launcher.sms(_phone!,
        body: _toHub
            ? 'Pickrush rider for batch #${b.batchNo}: heading to the station.'
            : _delivery
                ? 'Hi! This is your Pickrush rider. I am on my way with your parcel${stop!.parcelCount == 1 ? '' : 's'}${stop.codTotal > 0 ? '. Please prepare ${FormatUtils.peso(stop.codTotal)} (cash on delivery)' : ''}.'
                : 'Hi! This is your Pickrush rider for batch #${b.batchNo}. I am on my way to collect your parcels.');
  }

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// "STOP 2 OF 3 · PICKUP", or the station.
  String get _overline {
    if (_toHub) return _delivery ? 'BACK TO THE STATION' : 'DROP-OFF AT THE STATION';
    final what = switch (_stop!.kind) {
      'delivery' => 'DELIVERY',
      'return' => 'RETURN TO SELLER',
      _ => 'PICKUP',
    };
    return 'STOP ${_stop!.number} OF ${b.stops.length} · $what';
  }

  /// What the rider does when they get there.
  List<String> get _todo {
    if (_toHub) {
      if (_delivery) {
        return [
          if (b.toReturnCount > 0) 'Hand back ${_parcels(b.toReturnCount)} not delivered',
          if (b.toRemit > 0) 'Remit ${FormatUtils.peso(b.toRemit)} COD cash',
          if (b.toReturnCount == 0 && b.toRemit <= 0) 'Check in with the station',
        ];
      }
      return [
        'Hand over ${_parcels(b.carrying)}',
        if (b.notCollectedCount > 0) '${b.notCollectedCount} not collected: the station will reassign',
      ];
    }
    final stop = _stop!;
    final n = stop.open.length;
    return switch (stop.kind) {
      'delivery' => [
          'Deliver ${_parcels(n)}',
          if (stop.codTotal > 0) 'Collect ${FormatUtils.peso(stop.codTotal)} cash',
        ],
      'return' => ['Return ${_parcels(n)} to the seller'],
      _ => ['Collect ${_parcels(n)}'],
    };
  }

  static String _parcels(int n) => '$n ${n == 1 ? 'parcel' : 'parcels'}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.lg),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ),
            Text(_overline, style: AppTextStyles.overline.copyWith(color: AppColors.primaryDark)),
            const SizedBox(height: 4),
            Text(_name, style: AppTextStyles.h1),
            if (_address != null && _address!.isNotEmpty) ...[
              AppSpacing.gapSm,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_address!, style: AppTextStyles.body)),
                ],
              ),
            ],
            AppSpacing.gapMd,
            for (final line in _todo)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_box_outline_blank_rounded, size: 18, color: AppColors.primaryDark),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line, style: AppTextStyles.bodyStrong)),
                  ],
                ),
              ),
            AppSpacing.gapLg,
            _DirectionsCard(
              metres: _metres,
              hasPin: _pin != null,
              gpsProblem: _gpsProblem,
              waitingForGps: _fix == null && _gpsProblem == null,
              onOpenMaps: _openMaps,
              onFixGps: _fixGps,
            ),
            if (_phone != null) ...[
              AppSpacing.gapMd,
              Row(
                children: [
                  Expanded(
                    child: _ContactButton(
                      icon: Icons.call_outlined,
                      label: 'Call $_contact',
                      onTap: () => Launcher.call(_phone!),
                    ),
                  ),
                  AppSpacing.gapMd,
                  Expanded(
                    child: _ContactButton(icon: Icons.sms_outlined, label: 'Text', onTap: _text),
                  ),
                ],
              ),
            ],
            AppSpacing.gapMd,
            Center(
              child: TextButton.icon(
                onPressed: () => showReportProblem(context, b.id),
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('Report a problem'),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ArriveBar(
        hint: _arriveHint,
        hintIsWarning: !_alreadyArrived && _unlocked && _far,
        child: _alreadyArrived
            ? AppButton(
                label: _toHub ? 'Open handover checklist' : (_delivery ? 'Scan & deliver' : 'Scan waybills'),
                onPressed: () => _next(b),
              )
            : SlideToAccept(
                label: _toHub ? 'Arrived at Hub' : 'Arrived at Stop ${widget.stopNumber}',
                enabled: _unlocked,
                onSubmit: _arrive,
              ),
      ),
    );
  }

  /// The one line above the slider: why it is locked, a distance warning, or
  /// that the spot is recorded because there is no pin.
  String? get _arriveHint {
    if (_alreadyArrived) return null;
    final place = _toHub ? 'hub' : 'stop';
    if (!_unlocked) {
      return _fix == null ? 'Waiting for your location to unlock.' : 'Unlocks within ${b.arrivalRadiusM} m of the $place.';
    }
    if (_far) return "You're about ${LocationService.distanceLabel(_metres!)} away. Make sure you're at the right place.";
    if (_pin == null) return 'No map pin yet: your location is recorded when you slide.';
    return null;
  }
}

/// Distance, ETA and the button that opens turn-by-turn in Google Maps (or
/// fixes location access when that is the problem).
class _DirectionsCard extends StatelessWidget {
  const _DirectionsCard({
    required this.metres,
    required this.hasPin,
    required this.gpsProblem,
    required this.waitingForGps,
    required this.onOpenMaps,
    required this.onFixGps,
  });

  final double? metres;
  final bool hasPin;
  final LocationProblem? gpsProblem;
  final bool waitingForGps;
  final VoidCallback onOpenMaps;
  final VoidCallback onFixGps;

  @override
  Widget build(BuildContext context) {
    final known = metres != null && gpsProblem == null;
    final String status;
    if (gpsProblem != null) {
      status = gpsProblem!.message;
    } else if (!hasPin) {
      status = 'No map pin yet. Google Maps will search the address.';
    } else if (waitingForGps) {
      status = 'Finding your location…';
    } else {
      status = 'about ${LocationService.etaLabel(metres!)} away';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.lgAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (known)
            Text(LocationService.distanceLabel(metres!), style: AppTextStyles.display.copyWith(fontSize: 30)),
          Text(status, style: known ? AppTextStyles.body : AppTextStyles.bodyStrong),
          AppSpacing.gapMd,
          SizedBox(
            width: double.infinity,
            child: gpsProblem != null
                ? OutlinedButton.icon(
                    onPressed: onFixGps,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(gpsProblem!.openSettings ? 'Open settings' : 'Allow location'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      backgroundColor: AppColors.surface,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: onOpenMaps,
                    icon: const Icon(Icons.navigation_rounded, size: 20),
                    label: const Text('Open Google Maps'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(52),
                      textStyle: AppTextStyles.button,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
                    ),
                  ),
          ),
          if (gpsProblem == null) ...[
            const SizedBox(height: 6),
            Text('Come back here and slide "Arrived" when you get there.', style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryDark,
        side: const BorderSide(color: AppColors.primary),
        backgroundColor: AppColors.surface,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
      ),
    );
  }
}

/// Pinned to the bottom of the screen: an optional hint, then the slider.
class _ArriveBar extends StatelessWidget {
  const _ArriveBar({required this.child, this.hint, this.hintIsWarning = false});
  final Widget child;
  final String? hint;
  final bool hintIsWarning;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hint != null) ...[
                Row(
                  children: [
                    Icon(hintIsWarning ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                        size: 16, color: hintIsWarning ? AppColors.warning : AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(hint!,
                          style: AppTextStyles.caption.copyWith(color: hintIsWarning ? AppColors.warning : null)),
                    ),
                  ],
                ),
                AppSpacing.gapSm,
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}
