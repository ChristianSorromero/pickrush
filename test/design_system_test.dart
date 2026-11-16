import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rider_app/app_colors.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/models/earnings_models.dart';
import 'package:rider_app/widgets/section_card.dart';
import 'package:rider_app/riderpages/pickups/pickups_screen.dart';
import 'package:rider_app/widgets/active_task_bar.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/app_feedback.dart';
import 'package:rider_app/widgets/dashboard_top_bar.dart';
import 'package:rider_app/widgets/earnings_header.dart';
import 'package:rider_app/widgets/next_assignment_card.dart';

import 'batch_models_test.dart' show batchJson;

/// Phone width, plain theme (no font downloads), optional large text.
Future<void> pump(WidgetTester tester, Widget child, {double textScale = 1}) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: const Size(360, 800), textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child))),
    ),
  ));
}

RiderBatch batch({String status = 'accepted', String type = 'pickup'}) =>
    RiderBatch.fromJson({...batchJson(), 'status': status, 'type': type});

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Fonts can't be fetched in tests; ignore just that error.
  void ignoreFontErrors() {
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('google_fonts') || d.exceptionAsString().contains('GoogleFonts')) return;
      previous?.call(d);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  test('batch tones follow the batch status', () {
    expect(batchTone(batch(status: 'offered')), TaskTone.offer);
    expect(batchTone(batch()), TaskTone.active);
    expect(batchTone(batch(status: 'completed')), TaskTone.done);
    expect(batchTone(batch(status: 'cancelled')), TaskTone.muted);
  });

  test('batch filters split offers from work in progress', () {
    final offer = batch(status: 'offered');
    final pickup = batch();
    final delivery = batch(type: 'delivery');
    expect(BatchFilter.offers.matches(offer), isTrue);
    expect(BatchFilter.pickups.matches(offer), isFalse);
    expect(BatchFilter.pickups.matches(pickup), isTrue);
    expect(BatchFilter.deliveries.matches(delivery), isTrue);
    expect(BatchFilter.deliveries.matches(pickup), isFalse);
  });

  testWidgets('a loading button ignores taps, so nothing is sent twice', (tester) async {
    ignoreFontErrors();
    var taps = 0;
    await pump(tester, AppButton(label: 'Confirm', isLoading: true, onPressed: () => taps++));
    await tester.tap(find.byType(AppButton));
    await tester.pump();
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await pump(tester, AppButton(label: 'Confirm', onPressed: () => taps++));
    await tester.tap(find.byType(AppButton));
    expect(taps, 1);
  });

  testWidgets('batch card and active-task bar fit a phone at 1.3x text', (tester) async {
    ignoreFontErrors();
    var opened = 0;
    await pump(
      tester,
      Column(children: [
        BatchCard(batch: batch(), onTap: () => opened++),
        const SizedBox(height: 12),
        ActiveTaskBar(batch: batch(), moreCount: 2, onOpen: () => opened++),
      ]),
      textScale: 1.3,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // no overflow
    expect(find.text('#PK-0003'), findsOneWidget);
    expect(find.text('Picking up'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.tap(find.byType(BatchCard));
    expect(opened, 2);
  });

  testWidgets('the active-task bar hides when nothing is in progress', (tester) async {
    ignoreFontErrors();
    await pump(tester, ActiveTaskBar(batch: null, onOpen: () {}));
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('an error state offers a retry; offline says so', (tester) async {
    ignoreFontErrors();
    var retried = 0;
    await pump(tester, StateView.error(message: 'Could not reach the server.', offline: true, onRetry: () => retried++));
    await tester.pumpAndSettle();
    expect(find.text('You are offline'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });

  testWidgets('the offline banner shows only while check-ins fail', (tester) async {
    ignoreFontErrors();
    await pump(tester, const OfflineBanner(visible: false));
    expect(find.textContaining("Can't reach the server"), findsNothing);
    await pump(tester, OfflineBanner(visible: true, lastSyncAt: DateTime.now()));
    await tester.pumpAndSettle();
    expect(find.textContaining("Can't reach the server"), findsOneWidget);
  });

  testWidgets('Today widgets fit a phone at 1.3x text', (tester) async {
    ignoreFontErrors();
    await pump(
      tester,
      Column(children: [
        const DashboardTopBar(isOnline: true, hubName: 'Tanauan City Station, Batangas', hasNotifications: true),
        const SizedBox(height: 16),
        const EarningsHeader(amount: 12345.5, pickups: 128, delivered: 340),
        const SizedBox(height: 16),
        NextAssignmentCard(batch: batch(), onOpen: () {}),
        const SizedBox(height: 16),
        const NextAssignmentCard(isOnline: false),
      ]),
      textScale: 1.3,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Continue batch'), findsOneWidget);
  });

  test('an earnings range reads its total and days', () {
    final r = EarningsRange.fromJson({
      'from': '2026-11-10',
      'to': '2026-11-11',
      'total': {'earnings': 70, 'pickups': 1, 'deliveries': 2},
      'days': [
        {'date': '2026-11-10', 'earnings': 15, 'pickups': 1, 'deliveries': 0},
        {'date': '2026-11-11', 'earnings': 55, 'pickups': 0, 'deliveries': 2},
      ],
    });
    expect(r.total.earnings, 70.0);
    expect(r.total.deliveries, 2);
    expect(r.days.length, 2);
    expect(r.days.last.date, DateTime(2026, 11, 11));
  });

  testWidgets('a collapsible section shows its summary closed and its rows open', (tester) async {
    ignoreFontErrors();
    await pump(
      tester,
      const CollapsibleSection(
        icon: Icons.work_outline_rounded,
        title: 'Work assignment',
        summary: 'Tanauan City Station · Zone 3',
        children: [InfoRow(icon: Icons.warehouse_outlined, label: 'Station', value: 'Tanauan City Station')],
      ),
      textScale: 1.3,
    );
    expect(find.text('Tanauan City Station · Zone 3'), findsOneWidget);
    expect(find.text('Station'), findsNothing);

    await tester.tap(find.text('Work assignment'));
    await tester.pumpAndSettle();
    expect(find.text('Station'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Work assignment'));
    await tester.pumpAndSettle();
    expect(find.text('Station'), findsNothing);
  });
}
