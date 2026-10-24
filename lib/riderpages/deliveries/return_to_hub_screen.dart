import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/deliveries/return_handover_screen.dart';
import 'package:rider_app/riderpages/pickups/report_problem_sheet.dart';
import 'package:rider_app/riderpages/pickups/trip_screen.dart';
import 'package:rider_app/services/launcher.dart';
import 'package:rider_app/services/location_service.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/slide_to_accept.dart';
import 'package:rider_app/widgets/surface_card.dart';

/// Every stop is done: head back to the station with the parcels not
/// delivered and the COD cash. "Arrived at Hub" opens the handover checklist.
class ReturnToHubScreen extends StatefulWidget {
  const ReturnToHubScreen({super.key, required this.batch});

  final RiderBatch batch;

  @override
  State<ReturnToHubScreen> createState() => _ReturnToHubScreenState();
}

class _ReturnToHubScreenState extends State<ReturnToHubScreen> {
  StreamSubscription<GpsFix>? _gps;
  GpsFix? _fix;

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

  Future<void> _arrive() async {
    try {
      final fix = _fix ?? await locationService.current();
      final batch = await riderTasks.arriveAtHub(b.id, fix);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ReturnHandoverScreen(batch: batch)));
    } on TaskException catch (e) {
      _toast(e.message);
      rethrow;
    } on LocationProblem catch (e) {
      _toast(e.message);
      rethrow;
    }
  }

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hub = b.dropOff;
    final metres = _fix != null && hub?.pin != null ? LocationService.metres(_fix!, hub!.pin!) : null;
    final arrived = hub?.arrivedAt != null;

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
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Return to Hub', style: AppTextStyles.h1.copyWith(fontSize: 24)),
                            Text('#${b.batchNo} · ${b.deliveredCount} delivered, ${b.failedCount} not delivered',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.mdAll),
                        child: const Icon(Icons.local_shipping_rounded, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                  AppSpacing.gapLg,
                  Row(
                    children: [
                      Expanded(child: _Box(label: 'TO RETURN', value: '${b.toReturnCount} ${b.toReturnCount == 1 ? 'parcel' : 'parcels'}')),
                      AppSpacing.gapMd,
                      Expanded(child: _Box(label: 'TO REMIT', value: FormatUtils.peso(b.toRemit))),
                    ],
                  ),
                  if (hub != null) ...[
                    AppSpacing.gapLg,
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            children: [
                              Container(height: 10, width: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                              Expanded(child: Container(width: 2, color: AppColors.primary)),
                            ],
                          ),
                          AppSpacing.gapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('STATION', style: AppTextStyles.overline.copyWith(color: AppColors.primaryDark)),
                                Text(hub.name, style: AppTextStyles.h2),
                                if (hub.address != null) Text(hub.address!, style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AppSpacing.gapMd,
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.map_outlined, color: AppColors.textSecondary),
                title: Text('Estimated Arrival', style: AppTextStyles.bodyStrong),
                subtitle: Text(
                  metres == null
                      ? (hub?.pin == null ? 'Open the trip to navigate' : 'Finding your location…')
                      : '${LocationService.etaLabel(metres)} (${LocationService.distanceLabel(metres)})',
                  style: AppTextStyles.caption,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TripScreen(batch: b))),
              ),
            ),
            if (hub?.manager?.mobile != null) ...[
              AppSpacing.gapMd,
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.support_agent_rounded, color: AppColors.textSecondary),
                  title: Text(hub!.manager!.name, style: AppTextStyles.bodyStrong),
                  subtitle: Text('Hub manager', style: AppTextStyles.caption),
                  trailing: IconButton(
                    onPressed: () => Launcher.call(hub.manager!.mobile!),
                    icon: const Icon(Icons.call_outlined, color: AppColors.primaryDark),
                  ),
                ),
              ),
            ],
            AppSpacing.gapXl,
            if (arrived)
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => ReturnHandoverScreen(batch: b))),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Open handover checklist'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
                ),
              )
            else
              SlideToAccept(label: 'Arrived at Hub', onSubmit: _arrive),
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

class _Box extends StatelessWidget {
  const _Box({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: AppRadius.mdAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.overline.copyWith(fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.h2),
        ],
      ),
    );
  }
}
