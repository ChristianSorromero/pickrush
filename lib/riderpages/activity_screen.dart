import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/dashboard_models.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/activity_timeline.dart';

/// What the history shows: everything, pickups or deliveries.
enum ActivityKind {
  all('all', 'All activity', Icons.history_rounded),
  delivery('delivery', 'Deliveries', Icons.local_shipping_outlined),
  pickup('pickup', 'Pickups', Icons.inventory_2_outlined);

  const ActivityKind(this.api, this.label, this.icon);
  final String api;
  final String label;
  final IconData icon;

  /// The results the Result filter offers for this kind (API type, label).
  List<(String, String)> get results => [
        if (this != ActivityKind.delivery) ...const [('pickup', 'Picked up'), ('dropped_off', 'Dropped off')],
        if (this != ActivityKind.pickup)
          ...const [
            ('out_for_delivery', 'Out for delivery'),
            ('delivered', 'Delivered'),
            ('failed', 'Failed'),
            ('returned', 'Returned to seller'),
          ],
      ];
}

/// A date range from the Date filter: a preset ("Last 7 days") or a custom one.
class ActivityDates {
  const ActivityDates(this.label, this.from, this.to);
  final String label;
  final DateTime from;
  final DateTime to;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Today, yesterday, the last 7 days (today included) and this month.
  static List<ActivityDates> presets([DateTime? now]) {
    final today = _day(now ?? DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    return [
      ActivityDates('Today', today, today),
      ActivityDates('Yesterday', yesterday, yesterday),
      ActivityDates('Last 7 days', today.subtract(const Duration(days: 6)), today),
      ActivityDates('This month', DateTime(today.year, today.month), today),
    ];
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "Nov 3 – Nov 15", or "Nov 3" for one day; the year only when it is not this year.
  factory ActivityDates.custom(DateTimeRange range, [DateTime? now]) {
    final year = (now ?? DateTime.now()).year;
    String day(DateTime d) => '${_months[d.month - 1]} ${d.day}${d.year == year ? '' : ', ${d.year}'}';
    final from = _day(range.start), to = _day(range.end);
    return ActivityDates(from == to ? day(from) : '${day(from)} – ${day(to)}', from, to);
  }
}

/// "View All" from the dashboard: the full activity history, grouped by day,
/// older lines loading as the rider scrolls down. A picker chooses all,
/// deliveries or pickups; filters narrow it to a result and a date range.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, this.embedded = false});

  /// Shown inside the Tasks tab (no app bar of its own).
  final bool embedded;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  ActivityKind _kind = ActivityKind.all;
  String? _result;
  ActivityDates? _dates;

  final _items = <ActivityItem>[];
  String? _next;
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;

  /// Bumped on every filter change, so a page for old filters is dropped.
  int _generation = 0;

  bool get _filtered => _result != null || _dates != null;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _items.clear();
      _next = null;
      _loadedOnce = false;
      _loading = false;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || (_loadedOnce && _next == null)) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await riderTasks.activity(_kind.api,
          type: _result, from: _dates?.from, to: _dates?.to, before: _next);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _next = page.next;
        _loadedOnce = true;
      });
    } on TaskException catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e.message);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  void _setKind(ActivityKind kind) {
    if (kind == _kind) return;
    _kind = kind;
    // A result the new kind does not have (Delivered under Pickups) is dropped.
    if (_result != null && !kind.results.any((r) => r.$1 == _result)) _result = null;
    _reload();
  }

  void _clearFilters() {
    _result = null;
    _dates = null;
    _reload();
  }

  Future<void> _pickDates() async {
    final picked = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => _OptionSheet(
        title: 'Date',
        options: [
          ('Any time', null, _dates == null),
          for (final p in ActivityDates.presets()) (p.label, p, _dates?.label == p.label),
          ('Custom range…', const _Custom(), _dates != null && !ActivityDates.presets().any((p) => p.label == _dates!.label)),
        ],
      ),
    );
    if (!mounted || picked == null) return;
    if (picked is _Custom) {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
        initialDateRange: _dates == null ? null : DateTimeRange(start: _dates!.from, end: _dates!.to),
        helpText: 'Show activity from – to',
        saveText: 'Apply',
      );
      if (!mounted || range == null) return;
      _dates = ActivityDates.custom(range);
    } else {
      _dates = picked is ActivityDates ? picked : null;
    }
    _reload();
  }

  Future<void> _pickResult() async {
    final picked = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => _OptionSheet(
        title: 'Result',
        options: [
          ('All results', null, _result == null),
          for (final (type, label) in _kind.results) (label, type, _result == type),
        ],
      ),
    );
    if (!mounted || picked == null) return;
    _result = picked is String ? picked : null;
    _reload();
  }

  /// Consecutive lines of the same day, newest day first.
  List<(DateTime, List<ActivityItem>)> get _days {
    final days = <(DateTime, List<ActivityItem>)>[];
    for (final item in _items) {
      final at = item.at;
      final day = at == null ? DateTime(0) : DateTime(at.year, at.month, at.day);
      if (days.isEmpty || days.last.$1 != day) days.add((day, []));
      days.last.$2.add(item);
    }
    return days;
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  static String _dayLabel(DateTime day) {
    if (day.year == 0) return 'EARLIER';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ago = today.difference(day).inDays;
    if (ago == 0) return 'TODAY';
    if (ago == 1) return 'YESTERDAY';
    final date = '${_months[day.month - 1]} ${day.day}${day.year == now.year ? '' : ', ${day.year}'}';
    return ago < 7 ? '${_weekdays[day.weekday - 1].toUpperCase()} · ${date.toUpperCase()}' : date.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final resultLabel = _kind.results.where((r) => r.$1 == _result).map((r) => r.$2).firstOrNull;

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text('Activity', style: AppTextStyles.h2),
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, 0),
            child: _KindPicker(value: _kind, onChanged: _setKind),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.md),
            child: Row(
              children: [
                _FilterChip(
                  icon: Icons.calendar_today_outlined,
                  label: _dates?.label ?? 'Any time',
                  active: _dates != null,
                  onTap: _pickDates,
                ),
                AppSpacing.gapSm,
                _FilterChip(
                  icon: Icons.tune_rounded,
                  label: resultLabel ?? 'All results',
                  active: _result != null,
                  onTap: _pickResult,
                ),
                if (_filtered) ...[
                  AppSpacing.gapSm,
                  TextButton(
                    onPressed: _clearFilters,
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
                    child: const Text('Clear'),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _list() {
    final days = _days;
    final empty = _loadedOnce && _items.isEmpty;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _reload,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 400) _loadMore();
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
          children: [
            if (empty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxl),
                child: Column(
                  children: [
                    Icon(_filtered ? Icons.filter_alt_off_outlined : _kind.icon, size: 40, color: AppColors.textMuted),
                    AppSpacing.gapSm,
                    Text(
                      _filtered
                          ? 'Nothing matches these filters.'
                          : switch (_kind) {
                              ActivityKind.all => 'No activity yet.',
                              ActivityKind.pickup => 'No pickups yet.',
                              ActivityKind.delivery => 'No deliveries yet.',
                            },
                      style: AppTextStyles.body,
                    ),
                    if (_filtered)
                      TextButton(
                        onPressed: _clearFilters,
                        style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
                        child: const Text('Clear filters'),
                      ),
                  ],
                ),
              ),
            for (final (day, items) in days) ...[
              Text(_dayLabel(day), style: AppTextStyles.overline),
              AppSpacing.gapMd,
              ActivityTimeline(items: items, clockTime: true),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                      height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                ),
              )
            else if (_error != null)
              Center(
                child: Column(
                  children: [
                    Text(_error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _loadMore,
                      style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (_loadedOnce && _next == null && _items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: Text("That's everything.", style: AppTextStyles.caption)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Marks the "Custom range…" row of the Date sheet.
class _Custom {
  const _Custom();
}

/// All / Deliveries / Pickups, as a full-width dropdown.
class _KindPicker extends StatelessWidget {
  const _KindPicker({required this.value, required this.onChanged});
  final ActivityKind value;
  final ValueChanged<ActivityKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ActivityKind>(
      initialValue: value,
      onChanged: (k) => k == null ? null : onChanged(k),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
      borderRadius: AppRadius.mdAll,
      dropdownColor: AppColors.surface,
      style: AppTextStyles.bodyStrong.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll, borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll, borderSide: const BorderSide(color: AppColors.primary)),
      ),
      items: [
        for (final k in ActivityKind.values)
          DropdownMenuItem(
            value: k,
            child: Row(
              children: [
                Icon(k.icon, size: 20, color: AppColors.primaryDark),
                AppSpacing.gapSm,
                Text(k.label),
              ],
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primaryDark : AppColors.textSecondary;
    return Material(
      color: active ? AppColors.primarySoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.pillAll,
        side: BorderSide(color: active ? AppColors.primary : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.label.copyWith(color: color)),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down_rounded, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bottom sheet of choices; pops the chosen value. A null value pops
/// [_cleared] so "Any time" / "All results" can be told apart from dismissing.
class _OptionSheet extends StatelessWidget {
  const _OptionSheet({required this.title, required this.options});
  final String title;

  /// (label, value, selected)
  final List<(String, Object?, bool)> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.sm),
            child: Text(title, style: AppTextStyles.h2),
          ),
          for (final (label, value, selected) in options)
            ListTile(
              title: Text(label, style: AppTextStyles.bodyStrong),
              trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primaryDark) : null,
              onTap: () => Navigator.of(context).pop(value ?? _cleared),
            ),
          AppSpacing.gapSm,
        ],
      ),
    );
  }
}

/// Popped by the sheet for "Any time" / "All results".
const _cleared = _Cleared();

class _Cleared {
  const _Cleared();
}
