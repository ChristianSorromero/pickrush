import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/earnings_models.dart';
import 'package:rider_app/riderpages/wallet_parts.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/tab_header.dart';
import 'package:rider_app/widgets/icon_tile.dart';
import 'package:rider_app/widgets/section_card.dart';
import 'package:rider_app/widgets/stats_row.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';
import 'package:rider_app/widgets/app_feedback.dart';
import 'package:rider_app/riderpages/activity_screen.dart' show ActivityDates;
import 'package:rider_app/widgets/motion.dart';

/// Earnings tab: the wallet (what the rider can withdraw, the payslip waiting
/// for release, this week so far, deductions to dispute), what finished pickups
/// and deliveries earned (over a date range the rider picks, per batch) and the COD cash still to hand over (all of it).
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  EarningsData? _data;
  String? _error;
  ActivityDates _range = _earningsPresets()[1]; // this week
  EarningsRange? _rangeData;
  String? _rangeError;

  /// Bumped per range request, so an answer for an older range is dropped.
  int _rangeRequest = 0;
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

  Future<void> _loadRange() async {
    final request = ++_rangeRequest;
    if (_rangeError != null) setState(() => _rangeError = null);
    try {
      final data = await riderTasks.earningsRange(_range.from, _range.to);
      if (mounted && request == _rangeRequest) setState(() => _rangeData = data);
    } on TaskException catch (e) {
      if (mounted && request == _rangeRequest) setState(() => _rangeError = e.message);
    }
  }

  Future<void> _pickRange() async {
    final picked = await _showRangeSheet(context, _range);
    if (picked == null || !mounted) return;
    setState(() {
      _range = picked;
      _rangeData = null;
    });
    _loadRange();
  }

  Future<void> _load() async {
    _seenChanges = assignmentWatcher.changes;
    _loadRange();
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
            TabHeader(
              title: 'Wallet',
              subtitle: 'Your pay goes to your wallet. Hand over all the COD.',
              onNotificationsClosed: _load,
            ),
            AppSpacing.gapXl,
            if (d == null)
              _Status(error: _error, onRetry: _load)
            else ...[
              if (d.wallet != null) ...[
                WalletCard(wallet: d.wallet!, onChanged: _load),
                if (d.wallet!.deductions.isNotEmpty) ...[
                  AppSpacing.gapXl,
                  DeductionsCard(deductions: d.wallet!.deductions, onChanged: _load),
                ],
                AppSpacing.gapXl,
              ],
              _RangeButton(range: _range, onTap: _pickRange),
              AppSpacing.gapLg,
              if (_rangeData != null) ...[
                _Total(range: _range, total: _rangeData!.total),
                if (_rangeData!.days.length > 1) ...[
                  AppSpacing.gapLg,
                  _RangeChart(key: ValueKey(_rangeData), days: _rangeData!.days),
                ],
              ] else if (_rangeError != null)
                StateView.error(message: _rangeError!, onRetry: _loadRange)
              else
                const SkeletonGroup(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Skeleton(width: 140, height: 12),
                    SizedBox(height: 8),
                    Skeleton(width: 180, height: 34),
                    SizedBox(height: 16),
                    Skeleton(height: 84, radius: AppRadius.lg),
                  ]),
                ),
              AppSpacing.gapXl,
              _CodCard(cod: d.cod),
              AppSpacing.gapXl,
              if (d.wallet?.withdrawals.isNotEmpty ?? false) ...[
                WithdrawalsCard(withdrawals: d.wallet!.withdrawals),
                AppSpacing.gapXl,
              ],
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
                    : [_FinishedBatches(batches: d.batches)],
              ),
              AppSpacing.gapMd,
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      d.classRules.isNotEmpty
                          ? 'Pickup and delivery pay the same, by weight: ${_classRules(d.classRules)}. '
                              'Failed attempts don\'t count. Payslips close Sunday night and are released by Tuesday.'
                          : '${FormatUtils.peso(d.pickupRate)} per pickup · '
                              '${d.classRates.isEmpty ? '${FormatUtils.peso(d.deliveryRate)} per delivery' : 'delivery ${d.classRates.entries.map((e) => '${FormatUtils.peso(e.value)} ${e.key.toLowerCase()}').join(', ')}'}. '
                              'Failed attempts don\'t count. Payslips close Sunday night and are released by Tuesday.',
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

/// "₱15.00 up to 5 kg, ₱40.00 up to 10 kg, ₱60.00 up to 20 kg, ₱60.00 + ₱4.00/kg above 20 kg".
String _classRules(List<ClassRule> rules) {
  String kg(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  return rules
      .map((r) => r.perKgPay > 0
          ? '${FormatUtils.peso(r.pay)} + ${FormatUtils.peso(r.perKgPay)}/kg above ${kg(r.aboveKg)} kg'
          : '${FormatUtils.peso(r.pay)} up to ${kg(r.upToKg)} kg')
      .join(', ');
}

/// The quick picks in the range sheet: today, this week (from Monday), the
/// last 7 days, this month and last month.
List<ActivityDates> _earningsPresets([DateTime? now]) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final lastMonthEnd = DateTime(today.year, today.month, 0);
  return [
    ActivityDates('Today', today, today),
    ActivityDates('This week', monday, today),
    ActivityDates('Last 7 days', today.subtract(const Duration(days: 6)), today),
    ActivityDates('This month', DateTime(today.year, today.month), today),
    ActivityDates('Last month', DateTime(lastMonthEnd.year, lastMonthEnd.month), lastMonthEnd),
  ];
}

/// Quick picks plus "Custom range…" (calendar, up to a year back, not past today).
Future<ActivityDates?> _showRangeSheet(BuildContext context, ActivityDates current) async {
  const custom = 'custom';
  final presets = _earningsPresets();
  final choice = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    // Taller than the default half-screen sheet: size to the list, and scroll
    // on short phones or with large text.
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.sm),
            child: Text('Show earnings for', style: AppTextStyles.h2.copyWith(fontSize: 18)),
          ),
          for (final p in presets)
            ListTile(
              leading: Icon(
                p.label == current.label ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: p.label == current.label ? AppColors.primaryDark : AppColors.textMuted,
              ),
              title: Text(p.label, style: AppTextStyles.bodyStrong),
              subtitle: Text(_datesLabel(p.from, p.to), style: AppTextStyles.caption),
              onTap: () => Navigator.pop(context, p),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.date_range_rounded, color: AppColors.textPrimary),
            title: Text('Custom range…', style: AppTextStyles.bodyStrong),
            subtitle: Text('Pick a start and an end day', style: AppTextStyles.caption),
            onTap: () => Navigator.pop(context, custom),
          ),
          AppSpacing.gapSm,
        ],
      ),
      ),
    ),
  );
  if (choice is ActivityDates) return choice;
  if (choice != custom || !context.mounted) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final range = await showDateRangePicker(
    context: context,
    firstDate: today.subtract(const Duration(days: 365)),
    lastDate: today,
    initialDateRange: DateTimeRange(start: current.from, end: current.to),
    helpText: 'Earnings from – to',
    saveText: 'Show',
  );
  return range == null ? null : ActivityDates.custom(range);
}

/// "Nov 10 – Nov 16", or "Nov 16" for one day.
String _datesLabel(DateTime from, DateTime to) => ActivityDates.custom(DateTimeRange(start: from, end: to)).label;

/// The range in use; tap to change it.
class _RangeButton extends StatelessWidget {
  const _RangeButton({required this.range, required this.onTap});
  final ActivityDates range;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dates = _datesLabel(range.from, range.to);
    final isPreset = range.label != dates;
    return Semantics(
      button: true,
      label: 'Date range: ${range.label}${isPreset ? ', $dates' : ''}. Tap to change',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.98,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.button, side: const BorderSide(color: AppColors.border)),
          child: InkWell(
            borderRadius: AppRadius.button,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 22, color: AppColors.primaryDark),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(range.label, style: AppTextStyles.bodyStrong),
                        if (isPreset) Text(dates, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Text('Change', style: AppTextStyles.link),
                  const Icon(Icons.expand_more_rounded, color: AppColors.primaryDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.range, required this.total});
  final ActivityDates range;
  final EarningsTotal total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EARNED · ${range.label.toUpperCase()}', style: AppTextStyles.overline),
        const SizedBox(height: 4),
        ValueSwap(value: total.earnings, child: Text(FormatUtils.peso(total.earnings), style: AppTextStyles.display)),
        AppSpacing.gapLg,
        StatsRow(pickups: total.pickups, delivered: total.deliveries),
      ],
    );
  }
}

/// A bar per day of the range (scrolls sideways past two weeks), the last
/// day picked first. Tap a bar to see that day.
class _RangeChart extends StatefulWidget {
  const _RangeChart({super.key, required this.days});
  final List<EarningsDay> days;

  @override
  State<_RangeChart> createState() => _RangeChartState();
}

class _RangeChartState extends State<_RangeChart> {
  late int _selected = widget.days.length - 1;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  /// Weekday names for a week or less, day numbers for longer ranges.
  String _short(DateTime d) =>
      widget.days.length <= 7 ? (_isToday(d) ? 'Today' : _weekdays[d.weekday - 1]) : '${d.day}';

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final top = days.map((d) => d.earnings).fold<double>(0, (a, b) => b > a ? b : a);
    final picked = days[_selected.clamp(0, days.length - 1)];
    final pickedLabel =
        _isToday(picked.date) ? 'Today' : '${_weekdays[picked.date.weekday - 1]}, ${_datesLabel(picked.date, picked.date)}';
    final scroll = days.length > 14;

    final bars = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [for (var i = 0; i < days.length; i++) _bar(i, top, fixedWidth: scroll ? 30 : null)],
    );

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(pickedLabel, style: AppTextStyles.h2)),
              ValueSwap(
                value: _selected,
                alignment: Alignment.centerRight,
                child: Text(FormatUtils.peso(picked.earnings), style: AppTextStyles.numeric.copyWith(color: AppColors.success)),
              ),
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
            child: scroll ? SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true, child: bars) : bars,
          ),
        ],
      ),
    );
  }

  Widget _bar(int i, double top, {double? fixedWidth}) {
    final day = widget.days[i];
    final selected = i == _selected;
    final bar = Semantics(
      button: true,
      selected: selected,
      label: '${_datesLabel(day.date, day.date)}: ${FormatUtils.peso(day.earnings)}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selected = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.content),
              curve: AppMotion.enter,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: top <= 0 ? 6 : 6 + 94 * (day.earnings / top),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _short(day.date),
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? AppColors.primaryDark : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
    return fixedWidth != null ? SizedBox(width: fixedWidth, child: bar) : Expanded(child: bar);
  }
}

/// The 5 latest finished batches, the rest behind "Show more".
class _FinishedBatches extends StatefulWidget {
  const _FinishedBatches({required this.batches});
  final List<FinishedBatch> batches;

  static const shown = 5;

  @override
  State<_FinishedBatches> createState() => _FinishedBatchesState();
}

class _FinishedBatchesState extends State<_FinishedBatches> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final all = widget.batches;
    final more = all.length - _FinishedBatches.shown;
    return Column(
      children: [
        for (final b in all.take(_FinishedBatches.shown)) _BatchRow(batch: b),
        AnimatedSize(
          duration: AppMotion.duration(context, AppMotion.small),
          curve: AppMotion.change,
          alignment: Alignment.topCenter,
          child: _open && more > 0
              ? Column(children: [for (final b in all.skip(_FinishedBatches.shown)) _BatchRow(batch: b)])
              : const SizedBox(width: double.infinity),
        ),
        if (more > 0)
          TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            iconAlignment: IconAlignment.end,
            icon: AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: AppMotion.duration(context, AppMotion.small),
              child: const Icon(Icons.expand_more_rounded),
            ),
            label: Text(_open ? 'Show less' : 'Show $more more'),
          ),
      ],
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
          icon: Icons.outbox_outlined,
          label: 'Remitted this month',
          value: FormatUtils.peso(cod.remittedThisMonth),
        ),
        if (cod.lastAmount != null)
          InfoRow(
            icon: Icons.history_rounded,
            label: 'Last remittance${cod.lastAt != null ? ' · ${_date(cod.lastAt!)}' : ''}',
            value: FormatUtils.peso(cod.lastAmount!),
            trailing: switch (cod.lastStatus) {
              'disputed' => const TagChip.error(label: 'Disputed'),
              'awaiting_rider' => const TagChip.warning(label: 'Confirm at handover'),
              _ => const TagChip.success(label: 'Counted'),
            },
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
    return error == null
        ? const StateView.loading(skeleton: CardListSkeleton(count: 2))
        : StateView.error(message: error!, onRetry: onRetry);
  }
}

String _date(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}';
}
