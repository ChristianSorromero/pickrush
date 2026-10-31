import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/earnings_models.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/icon_tile.dart';
import 'package:rider_app/widgets/section_card.dart';
import 'package:rider_app/widgets/stats_row.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

enum _Period { today, week, month }

/// Earnings tab: what finished pickups and deliveries earned (today, this week,
/// this month, the last 7 days, per batch) and the COD cash still to remit.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  EarningsData? _data;
  String? _error;
  _Period _period = _Period.week;
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
      final data = await riderTasks.earnings();
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } on TaskException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
          children: [
            Text('Earnings', style: AppTextStyles.h1),
            Text('From your finished pickups and deliveries', style: AppTextStyles.body),
            AppSpacing.gapXl,
            if (d == null)
              _Status(error: _error, onRetry: _load)
            else ...[
              _PeriodTabs(value: _period, onChanged: (p) => setState(() => _period = p)),
              AppSpacing.gapLg,
              _Total(period: _period, total: switch (_period) {
                _Period.today => d.today,
                _Period.week => d.week,
                _Period.month => d.month,
              }),
              AppSpacing.gapLg,
              _WeekChart(days: d.days),
              AppSpacing.gapXl,
              _CodCard(cod: d.cod),
              AppSpacing.gapXl,
              SectionCard(
                title: 'Finished batches',
                children: d.batches.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                          child: Center(
                            child: Text('Finished batches appear here.', style: AppTextStyles.caption),
                          ),
                        ),
                      ]
                    : [for (final b in d.batches) _BatchRow(batch: b)],
              ),
              AppSpacing.gapMd,
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${FormatUtils.peso(d.pickupRate)} per pickup · ${FormatUtils.peso(d.deliveryRate)} per delivery. '
                      'Failed attempts don\'t count. Your station handles payouts.',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapLg,
            ],
          ],
        ),
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.value, required this.onChanged});
  final _Period value;
  final ValueChanged<_Period> onChanged;

  static const _labels = {_Period.today: 'Today', _Period.week: 'This week', _Period.month: 'This month'};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final p in _Period.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: p == value ? AppColors.primary : Colors.transparent,
                    borderRadius: AppRadius.pillAll,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _labels[p]!,
                    style: AppTextStyles.label.copyWith(
                        color: p == value ? Colors.white : AppColors.textSecondary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.period, required this.total});
  final _Period period;
  final EarningsTotal total;

  @override
  Widget build(BuildContext context) {
    final label = switch (period) {
      _Period.today => "TODAY'S EARNINGS",
      _Period.week => 'EARNINGS THIS WEEK',
      _Period.month => 'EARNINGS THIS MONTH',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.overline),
        const SizedBox(height: 4),
        Text(FormatUtils.peso(total.earnings), style: AppTextStyles.display),
        AppSpacing.gapLg,
        StatsRow(pickups: total.pickups, delivered: total.deliveries),
      ],
    );
  }
}

/// Seven bars, today in coral. Tap a bar to see that day.
class _WeekChart extends StatefulWidget {
  const _WeekChart({required this.days});
  final List<EarningsDay> days;

  @override
  State<_WeekChart> createState() => _WeekChartState();
}

class _WeekChartState extends State<_WeekChart> {
  late int _selected = widget.days.length - 1;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    if (days.isEmpty) return const SizedBox.shrink();
    final top = days.map((d) => d.earnings).fold<double>(0, (a, b) => b > a ? b : a);
    final picked = days[_selected.clamp(0, days.length - 1)];
    final isToday = _selected == days.length - 1;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Last 7 days', style: AppTextStyles.h2),
              const Spacer(),
              Text(isToday ? 'Today' : _weekdays[picked.date.weekday - 1], style: AppTextStyles.caption),
              const SizedBox(width: 6),
              Text(FormatUtils.peso(picked.earnings),
                  style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primaryDark)),
            ],
          ),
          Text(
            '${picked.pickups} ${picked.pickups == 1 ? 'pickup' : 'pickups'} · '
            '${picked.deliveries} ${picked.deliveries == 1 ? 'delivery' : 'deliveries'}',
            style: AppTextStyles.caption,
          ),
          AppSpacing.gapLg,
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selected = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            height: top <= 0 ? 6 : 6 + 94 * (days[i].earnings / top),
                            decoration: BoxDecoration(
                              color: i == _selected
                                  ? AppColors.primary
                                  : (i == days.length - 1 ? AppColors.primary.withValues(alpha: 0.45) : AppColors.primarySoft),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            i == days.length - 1 ? 'Today' : _weekdays[days[i].date.weekday - 1],
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight: i == _selected ? FontWeight.w800 : FontWeight.w500,
                              color: i == _selected ? AppColors.primaryDark : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cash collected from buyers and not yet handed to the station.
class _CodCard extends StatelessWidget {
  const _CodCard({required this.cod});
  final CodSummary cod;

  @override
  Widget build(BuildContext context) {
    final share = cod.limit <= 0 ? 0.0 : (cod.inHand / cod.limit).clamp(0.0, 1.0);
    final high = share >= 0.8;
    return SectionCard(
      title: 'Cash on delivery',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(
                    icon: Icons.payments_outlined,
                    size: 36,
                    color: high ? AppColors.warning : AppColors.primaryDark,
                    background: high ? AppColors.warningSoft : AppColors.primarySoft,
                  ),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cash on hand', style: AppTextStyles.caption),
                        Text(FormatUtils.peso(cod.inHand), style: AppTextStyles.h2.copyWith(fontSize: 20)),
                      ],
                    ),
                  ),
                  cod.inHand > 0
                      ? const TagChip.warning(label: 'Remit at station')
                      : const TagChip.success(label: 'All remitted'),
                ],
              ),
              if (cod.limit > 0) ...[
                AppSpacing.gapMd,
                ClipRRect(
                  borderRadius: AppRadius.pillAll,
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    color: high ? AppColors.warning : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  high
                      ? 'Close to your ${FormatUtils.peso(cod.limit)} COD limit. Remit soon to keep getting deliveries.'
                      : 'COD limit ${FormatUtils.peso(cod.limit)}',
                  style: AppTextStyles.caption.copyWith(color: high ? AppColors.warning : null),
                ),
              ],
            ],
          ),
        ),
        InfoRow(
          icon: Icons.account_balance_outlined,
          label: 'Remitted this month',
          value: FormatUtils.peso(cod.remittedThisMonth),
        ),
        if (cod.lastAmount != null)
          InfoRow(
            icon: Icons.receipt_long_outlined,
            label: 'Last remittance${cod.lastAt != null ? ' · ${_date(cod.lastAt!)}' : ''}',
            value: FormatUtils.peso(cod.lastAmount!),
            trailing: cod.lastStatus == 'disputed'
                ? const TagChip(label: 'Disputed')
                : const TagChip.success(label: 'Counted'),
          ),
      ],
    );
  }
}

class _BatchRow extends StatelessWidget {
  const _BatchRow({required this.batch});
  final FinishedBatch batch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          IconTile(
            icon: batch.isDelivery ? Icons.local_shipping_outlined : Icons.inventory_2_outlined,
            size: 36,
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${batch.batchNo}', style: AppTextStyles.bodyStrong),
                Text(
                  [
                    batch.isDelivery ? 'Delivery' : 'Pickup',
                    '${batch.parcels} ${batch.parcels == 1 ? 'parcel' : 'parcels'}',
                    if (batch.completedAt != null) _date(batch.completedAt!),
                  ].join(' · '),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Text('+${FormatUtils.peso(batch.earned)}',
              style: AppTextStyles.bodyStrong.copyWith(color: AppColors.success)),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.error, required this.onRetry});
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: error == null
            ? const CircularProgressIndicator(color: AppColors.primary)
            : Column(
                children: [
                  Text(error!, textAlign: TextAlign.center, style: AppTextStyles.body),
                  AppSpacing.gapLg,
                  AppButton(label: 'Try again', onPressed: onRetry, expand: false),
                ],
              ),
      ),
    );
  }
}

String _date(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}';
}
