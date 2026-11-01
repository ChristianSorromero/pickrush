import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/dashboard_models.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/activity_timeline.dart';

/// "View All" from the dashboard: the full activity history, pickups and
/// deliveries on separate tabs, grouped by day, older lines loading as the
/// rider scrolls down.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Activity', style: AppTextStyles.h2),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            labelStyle: AppTextStyles.bodyStrong,
            tabs: const [
              Tab(icon: Icon(Icons.inventory_2_outlined, size: 20), text: 'Pickups'),
              Tab(icon: Icon(Icons.local_shipping_outlined, size: 20), text: 'Deliveries'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ActivityList(kind: 'pickup'),
            _ActivityList(kind: 'delivery'),
          ],
        ),
      ),
    );
  }
}

class _ActivityList extends StatefulWidget {
  const _ActivityList({required this.kind});

  /// pickup or delivery.
  final String kind;

  @override
  State<_ActivityList> createState() => _ActivityListState();
}

class _ActivityListState extends State<_ActivityList> with AutomaticKeepAliveClientMixin {
  final _items = <ActivityItem>[];
  String? _next;
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;

  @override
  bool get wantKeepAlive => true; // keep the list when switching tabs

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    _items.clear();
    _next = null;
    _loadedOnce = false;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || (_loadedOnce && _next == null)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await riderTasks.activity(widget.kind, before: _next);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _next = page.next;
        _loadedOnce = true;
      });
    } on TaskException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    super.build(context);
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
                    Icon(widget.kind == 'pickup' ? Icons.inventory_2_outlined : Icons.local_shipping_outlined,
                        size: 40, color: AppColors.textMuted),
                    AppSpacing.gapSm,
                    Text(widget.kind == 'pickup' ? 'No pickups yet.' : 'No deliveries yet.', style: AppTextStyles.body),
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
