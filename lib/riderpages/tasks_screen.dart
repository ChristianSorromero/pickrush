import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/riderpages/activity_screen.dart';
import 'package:rider_app/riderpages/pickups/pickups_screen.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/widgets/tab_header.dart';

/// The segments of the Tasks tab.
enum TaskSegment { offers, pickups, deliveries, done }

/// Tasks tab: new offers, pickups and deliveries in progress, and the done
/// history — one place for every batch instead of two look-alike tabs.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.segment, required this.onSegment});

  final TaskSegment segment;
  final ValueChanged<TaskSegment> onSegment;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.md),
            child: TabHeader(title: 'Tasks', subtitle: 'Batches from your station'),
          ),
          ListenableBuilder(
            listenable: assignmentWatcher,
            builder: (context, _) => _Segments(
              value: widget.segment,
              onChanged: widget.onSegment,
              dots: {
                if (assignmentWatcher.offeredBatchIds.isNotEmpty) TaskSegment.offers,
              },
            ),
          ),
          Expanded(
            child: switch (widget.segment) {
              TaskSegment.offers => const BatchList(key: ValueKey('offers'), filter: BatchFilter.offers),
              TaskSegment.pickups => const BatchList(key: ValueKey('pickups'), filter: BatchFilter.pickups),
              TaskSegment.deliveries => const BatchList(key: ValueKey('deliveries'), filter: BatchFilter.deliveries),
              TaskSegment.done => const ActivityScreen(embedded: true),
            },
          ),
        ],
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.value, required this.onChanged, required this.dots});

  final TaskSegment value;
  final ValueChanged<TaskSegment> onChanged;
  final Set<TaskSegment> dots;

  static const _labels = {
    TaskSegment.offers: 'Offers',
    TaskSegment.pickups: 'Pickups',
    TaskSegment.deliveries: 'Deliveries',
    TaskSegment.done: 'Done',
  };

  @override
  Widget build(BuildContext context) {
    final d = AppMotion.duration(context, AppMotion.small);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            for (final s in TaskSegment.values)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: s == value,
                  child: InkWell(
                    borderRadius: AppRadius.pillAll,
                    onTap: () => onChanged(s),
                    child: AnimatedContainer(
                      duration: d,
                      curve: AppMotion.change,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s == value ? AppColors.textPrimary : Colors.transparent,
                        borderRadius: AppRadius.pillAll,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _labels[s]!,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: AppTextStyles.label
                                  .copyWith(color: s == value ? Colors.white : AppColors.textSecondary),
                            ),
                          ),
                          if (dots.contains(s)) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(color: AppColors.info, shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
