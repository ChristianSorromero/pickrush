import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/pickups/handover_screen.dart';
import 'package:rider_app/riderpages/pickups/report_problem_sheet.dart';
import 'package:rider_app/riderpages/pickups/trip_screen.dart';
import 'package:rider_app/services/launcher.dart';
import 'package:rider_app/services/location_service.dart';
import 'package:rider_app/widgets/icon_tile.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

/// Every stop is done: take the parcels to the station. Shows the station,
/// how far it is, what to do there and who to call.
class HubHandoverScreen extends StatefulWidget {
  const HubHandoverScreen({super.key, required this.batch});

  final RiderBatch batch;

  @override
  State<HubHandoverScreen> createState() => _HubHandoverScreenState();
}

class _HubHandoverScreenState extends State<HubHandoverScreen> {
  StreamSubscription<GpsFix>? _gps;
  GpsFix? _fix;
  bool _stepsOpen = true;

  RiderBatch get b => widget.batch;

  @override
  void initState() {
    super.initState();
    if (b.dropOff?.pin != null) {
      _gps = locationService.watch().listen((f) => setState(() => _fix = f), onError: (_) {});
    }
  }

  @override
  void dispose() {
    _gps?.cancel();
    super.dispose();
  }

  void _goToHub() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => b.dropOff?.arrivedAt != null
          ? HandoverScreen(batch: b)
          : TripScreen(batch: b),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hub = b.dropOff;
    final metres = _fix != null && hub?.pin != null ? LocationService.metres(_fix!, hub!.pin!) : null;
    final stopsDone = b.stops.length;
    final last = b.lastPickupAt;
    final arrived = hub?.arrivedAt != null;

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
            Text('Head to ${hub?.name ?? 'the station'}', style: AppTextStyles.h1),
            Text('Batch #${b.batchNo} · All pickups complete', style: AppTextStyles.body),
            AppSpacing.gapLg,
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TagChip.success(label: '✓ Completed'),
                  AppSpacing.gapSm,
                  Text('All $stopsDone ${stopsDone == 1 ? 'pickup' : 'pickups'} completed',
                      style: AppTextStyles.h2),
                  const SizedBox(height: 2),
                  Text(
                    "You're carrying ${b.carrying} ${b.carrying == 1 ? 'parcel' : 'parcels'}. Take them to the station now.",
                    style: AppTextStyles.body,
                  ),
                  if (b.notCollectedCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${b.notCollectedCount} not collected: the station will reassign ${b.notCollectedCount == 1 ? 'it' : 'them'}.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark),
                    ),
                  ],
                  if (last != null) ...[
                    AppSpacing.gapSm,
                    Text('Last pickup completed ${TimeOfDay.fromDateTime(last).format(context)}',
                        style: AppTextStyles.caption),
                  ],
                ],
              ),
            ),
            AppSpacing.gapLg,
            _Steps(stops: stopsDone, atHub: arrived),
            AppSpacing.gapLg,
            if (hub != null)
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const IconTile(icon: Icons.apartment_rounded, size: 40,
                            color: AppColors.textPrimary, background: AppColors.background),
                        AppSpacing.gapMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(hub.name, style: AppTextStyles.h2),
                              if (hub.address != null) Text(hub.address!, style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,
                    Row(
                      children: [
                        Expanded(
                          child: _Box(
                            label: 'DISTANCE',
                            value: metres == null ? '—' : LocationService.distanceLabel(metres),
                          ),
                        ),
                        AppSpacing.gapMd,
                        Expanded(
                          child: _Box(
                            label: 'EST. TIME',
                            value: metres == null ? '—' : LocationService.etaLabel(metres),
                          ),
                        ),
                      ],
                    ),
                    if (hub.pin == null) ...[
                      AppSpacing.gapSm,
                      Text('The station has no map pin yet, so distance is unknown.',
                          style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
            AppSpacing.gapMd,
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    title: Text('Handover steps', style: AppTextStyles.bodyStrong),
                    trailing: Icon(_stepsOpen ? Icons.expand_less : Icons.expand_more),
                    onTap: () => setState(() => _stepsOpen = !_stepsOpen),
                  ),
                  if (_stepsOpen)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                      child: Text(
                        '1. Park in the rider zone.\n'
                        '2. Tell the staff your batch number: #${b.batchNo}.\n'
                        '3. Hand over each parcel; they scan it in.\n'
                        '4. Wait until every parcel shows "Received" in the app.',
                        style: AppTextStyles.body,
                      ),
                    ),
                  if (hub?.manager != null) ...[
                    const Divider(height: 1, color: AppColors.border),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Text(hub!.manager!.name.characters.first,
                            style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primaryDark)),
                      ),
                      title: Text(hub.manager!.name, style: AppTextStyles.bodyStrong),
                      subtitle: Text('Hub Manager', style: AppTextStyles.caption),
                      trailing: hub.manager!.mobile == null
                          ? null
                          : OutlinedButton.icon(
                              onPressed: () => Launcher.call(hub.manager!.mobile!),
                              icon: const Icon(Icons.call_outlined, size: 16),
                              label: const Text('CALL'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryDark,
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
            AppSpacing.gapXl,
            if (!arrived)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('Hub handover unlocks when you arrive.', style: AppTextStyles.caption),
                ],
              ),
            AppSpacing.gapSm,
            ElevatedButton.icon(
              onPressed: _goToHub,
              icon: Icon(arrived ? Icons.fact_check_outlined : Icons.navigation_rounded, size: 18),
              label: Text(arrived ? 'Open handover checklist' : 'Navigate to ${hub?.name ?? 'station'}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
              ),
            ),
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
    );
  }
}

/// One checked dot per stop, then the hub (ringed until the rider arrives).
class _Steps extends StatelessWidget {
  const _Steps({required this.stops, required this.atHub});
  final int stops;
  final bool atHub;

  @override
  Widget build(BuildContext context) {
    Widget done() => Container(
          height: 22,
          width: 22,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
        );
    final hub = Container(
      height: 26,
      width: 26,
      decoration: BoxDecoration(
        color: atHub ? AppColors.primary : AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 3),
      ),
      child: atHub ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
    );
    return Row(
      children: [
        for (var i = 0; i < stops; i++) ...[
          done(),
          Expanded(child: Container(height: 2, color: AppColors.primary)),
        ],
        hub,
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.overline.copyWith(fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.h2),
        ],
      ),
    );
  }
}
