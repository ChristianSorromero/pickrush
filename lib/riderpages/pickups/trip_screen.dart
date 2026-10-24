import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
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
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

/// On the way to a seller ([stopNumber]) or, without one, to the station.
///
/// Turn-by-turn happens in the free Google Maps app; this screen keeps what the
/// rider needs around it: live distance and ETA from the phone's GPS, call /
/// text, and the "Arrived" slider. The slider only locks to the pin when the
/// server enforces the arrival radius; otherwise the distance is just recorded.
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

  BatchStop? get _stop => widget.stopNumber == null
      ? null
      : widget.batch.stops.firstWhere((s) => s.number == widget.stopNumber);
  bool get _toHub => widget.stopNumber == null;

  Pin? get _pin => _toHub ? widget.batch.dropOff?.pin : _stop?.pin;
  bool get _delivery => widget.batch.isDelivery;
  String get _name => _toHub ? (widget.batch.dropOff?.name ?? 'Station') : _stop!.name;
  String? get _address => _toHub ? widget.batch.dropOff?.address : _stop?.address;
  String? get _phone => _toHub ? widget.batch.dropOff?.manager?.mobile : _stop?.mobile;
  bool get _alreadyArrived => _toHub ? widget.batch.dropOff?.arrivedAt != null : _stop!.hasArrived;

  double? get _metres =>
      _fix != null && _pin != null ? LocationService.metres(_fix!, _pin!) : null;

  /// Far from a pinned stop (only a warning unless the radius is enforced).
  bool get _far {
    final m = _metres;
    return m != null && m > widget.batch.arrivalRadiusM + math.min(_fix!.accuracy, 50);
  }

  /// Allowed to slide "Arrived" (the server checks again).
  bool get _unlocked {
    if (!widget.batch.arrivalLocked) return true; // GPS is read when sliding
    if (_fix == null) return false;
    if (_pin == null) return true; // no pin: recorded, not checked
    return _metres! <= widget.batch.arrivalRadiusM + math.min(_fix!.accuracy, 50);
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
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open Google Maps.')));
    }
  }

  Future<void> _arrive() async {
    try {
      final fix = _fix ?? await locationService.current();
      final batch = _toHub
          ? await riderTasks.arriveAtHub(widget.batch.id, fix)
          : await riderTasks.arriveAtStop(widget.batch.id,
              [for (final i in _stop!.open) i.assignmentId], fix);
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

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final metres = _metres;
    final radius = widget.batch.arrivalRadiusM;

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
            AppSpacing.gapSm,
            _RoutePanel(
              toHub: _toHub,
              name: _name,
              metres: metres,
              hasPin: _pin != null,
              gpsProblem: _gpsProblem,
              waitingForGps: _fix == null && _gpsProblem == null,
              onOpenMaps: _openMaps,
              onFixGps: () async {
                if (_gpsProblem?.openSettings ?? false) await locationService.openSettings();
                _listen();
              },
            ),
            AppSpacing.gapMd,
            if (_phone != null)
              Row(
                children: [
                  _RoundAction(icon: Icons.call_outlined, label: 'Call', onTap: () => Launcher.call(_phone!)),
                  AppSpacing.gapMd,
                  _RoundAction(
                    icon: Icons.sms_outlined,
                    label: 'Text',
                    onTap: () => Launcher.sms(_phone!,
                        body: _toHub
                            ? 'Pickrush rider for batch #${widget.batch.batchNo}: heading to the station.'
                            : _delivery
                                ? 'Hi! This is your Pickrush rider. I am on my way with your parcel${_stop!.parcelCount == 1 ? '' : 's'}${_stop!.codTotal > 0 ? '. Please prepare ₱${_stop!.codTotal.toStringAsFixed(2)} (cash on delivery)' : ''}.'
                                : 'Hi! This is your Pickrush rider for batch #${widget.batch.batchNo}. I am on my way to collect your parcels.'),
                  ),
                  const Spacer(),
                  Text(_toHub ? 'Hub manager' : (_stop!.kind == 'delivery' ? 'Buyer' : 'Seller'), style: AppTextStyles.caption),
                ],
              ),
            AppSpacing.gapMd,
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _toHub
                          ? const TagChip.warning(label: 'Heading to hub')
                          : TagChip.warning(label: _delivery ? 'Out for delivery' : 'Ready for pickup'),
                      const Spacer(),
                      if (metres != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(LocationService.distanceLabel(metres),
                                style: AppTextStyles.h2.copyWith(fontSize: 22)),
                            Text(LocationService.etaLabel(metres), style: AppTextStyles.caption),
                          ],
                        ),
                    ],
                  ),
                  AppSpacing.gapSm,
                  Text('#${widget.batch.batchNo}', style: AppTextStyles.h1.copyWith(fontSize: 24)),
                  Text(_name, style: AppTextStyles.body),
                  if (_address != null && _address!.isNotEmpty) ...[
                    AppSpacing.gapMd,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primaryDark),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_address!, style: AppTextStyles.bodyStrong)),
                      ],
                    ),
                  ],
                  if (!_toHub && _stop != null) ...[
                    AppSpacing.gapSm,
                    Text('${_stop!.open.length} ${_stop!.open.length == 1 ? 'parcel' : 'parcels'} to ${_delivery ? 'deliver' : 'collect'}'
                        '${_delivery && _stop!.codTotal > 0 ? ' · collect ₱${_stop!.codTotal.toStringAsFixed(2)}' : ''}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                  AppSpacing.gapLg,
                  if (_alreadyArrived)
                    AppButton(
                      label: _toHub ? 'Open handover checklist' : (_delivery ? 'Scan & deliver' : 'Scan waybills'),
                      onPressed: () => _next(widget.batch),
                    )
                  else ...[
                    if (!_unlocked)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _fix == null
                                    ? 'Waiting for your location to unlock.'
                                    : 'Unlocks within $radius m of the ${_toHub ? 'hub' : 'stop'}.',
                                style: AppTextStyles.caption,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_far)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          "You're about ${LocationService.distanceLabel(_metres!)} from the ${_toHub ? 'hub' : 'stop'}. Make sure you're at the right place.",
                          style: AppTextStyles.caption.copyWith(color: AppColors.warning),
                        ),
                      )
                    else if (_pin == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          _toHub
                              ? 'The station has no map pin yet; your location is recorded when you slide.'
                              : 'This seller has no shop pin yet; your location is recorded when you slide.',
                          style: AppTextStyles.caption,
                        ),
                      ),
                    SlideToAccept(
                      label: _toHub ? 'Arrived at Hub' : 'Arrived at Stop ${widget.stopNumber}',
                      enabled: _unlocked,
                      onSubmit: _arrive,
                    ),
                  ],
                  Center(
                    child: TextButton.icon(
                      onPressed: () => showReportProblem(context, widget.batch.id),
                      icon: const Icon(Icons.flag_outlined, size: 16),
                      label: const Text('Report a problem'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stands in for the map: where you are, where you are going, and the
/// button that opens turn-by-turn in Google Maps.
class _RoutePanel extends StatelessWidget {
  const _RoutePanel({
    required this.toHub,
    required this.name,
    required this.metres,
    required this.hasPin,
    required this.gpsProblem,
    required this.waitingForGps,
    required this.onOpenMaps,
    required this.onFixGps,
  });

  final bool toHub;
  final String name;
  final double? metres;
  final bool hasPin;
  final LocationProblem? gpsProblem;
  final bool waitingForGps;
  final VoidCallback onOpenMaps;
  final VoidCallback onFixGps;

  @override
  Widget build(BuildContext context) {
    final String status;
    if (gpsProblem != null) {
      status = gpsProblem!.message;
    } else if (waitingForGps) {
      status = 'Finding your location…';
    } else if (!hasPin) {
      status = 'No map pin yet. Google Maps will search the address.';
    } else {
      status = '${LocationService.distanceLabel(metres!)} away · about ${LocationService.etaLabel(metres!)}';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const _Dot(icon: Icons.two_wheeler_rounded, filled: true),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, c) => Row(
                    children: List.generate(
                      (c.maxWidth / 10).floor(),
                      (i) => Container(
                        width: 5,
                        height: 2,
                        margin: const EdgeInsets.only(right: 5),
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              _Dot(icon: toHub ? Icons.apartment_rounded : Icons.storefront_rounded, filled: false),
            ],
          ),
          AppSpacing.gapSm,
          Row(
            children: [
              Text('You', style: AppTextStyles.caption),
              const Spacer(),
              Flexible(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          AppSpacing.gapMd,
          Text(status, textAlign: TextAlign.center, style: AppTextStyles.bodyStrong),
          AppSpacing.gapMd,
          SizedBox(
            width: double.infinity,
            child: gpsProblem != null
                ? OutlinedButton.icon(
                    onPressed: onFixGps,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(gpsProblem!.openSettings ? 'Open settings' : 'Allow location'),
                    style: _outlined,
                  )
                : ElevatedButton.icon(
                    onPressed: onOpenMaps,
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Navigate in Google Maps'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text('Come back here and slide "Arrived" when you get there.',
              textAlign: TextAlign.center, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  static final _outlined = OutlinedButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    side: const BorderSide(color: AppColors.border),
    backgroundColor: AppColors.surface,
    minimumSize: const Size.fromHeight(46),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.icon, required this.filled});
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: filled ? AppColors.primary : AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Icon(icon, size: 20, color: filled ? Colors.white : AppColors.primaryDark),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Icon(icon, size: 20, color: AppColors.primaryDark),
        ),
      ),
    );
  }
}
