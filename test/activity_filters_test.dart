import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rider_app/riderpages/activity_screen.dart';
import 'package:rider_app/services/rider_task_service.dart';

void main() {
  final now = DateTime(2026, 11, 15, 14, 30);

  test('date presets are whole days ending today', () {
    final presets = {for (final p in ActivityDates.presets(now)) p.label: (p.from, p.to)};

    expect(presets['Today'], (DateTime(2026, 11, 15), DateTime(2026, 11, 15)));
    expect(presets['Yesterday'], (DateTime(2026, 11, 14), DateTime(2026, 11, 14)));
    expect(presets['Last 7 days'], (DateTime(2026, 11, 9), DateTime(2026, 11, 15)));
    expect(presets['This month'], (DateTime(2026, 11, 1), DateTime(2026, 11, 15)));
  });

  test('a custom range is labelled from – to, with the year only when it is not this year', () {
    expect(ActivityDates.custom(DateTimeRange(start: DateTime(2026, 11, 3), end: DateTime(2026, 11, 15)), now).label,
        'Nov 3 – Nov 15');
    expect(ActivityDates.custom(DateTimeRange(start: DateTime(2026, 11, 3), end: DateTime(2026, 11, 3)), now).label, 'Nov 3');
    expect(ActivityDates.custom(DateTimeRange(start: DateTime(2025, 12, 28), end: DateTime(2026, 1, 2)), now).label,
        'Dec 28, 2025 – Jan 2');
  });

  test('each kind offers only its own results', () {
    List<String> types(ActivityKind k) => [for (final r in k.results) r.$1];

    expect(types(ActivityKind.pickup), ['pickup', 'dropped_off']);
    expect(types(ActivityKind.delivery), ['out_for_delivery', 'delivered', 'failed', 'returned']);
    expect(types(ActivityKind.all), [...types(ActivityKind.pickup), ...types(ActivityKind.delivery)]);
  });

  test('days go to the API as yyyy-mm-dd', () {
    expect(RiderTaskService.apiDate(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
  });
}
