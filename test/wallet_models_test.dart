import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/models/earnings_models.dart';
import 'package:rider_app/models/wallet_models.dart';

void main() {
  Map<String, dynamic> earnings({Map<String, dynamic>? wallet}) => {
        'rates': {'pickup': 15, 'delivery': 15},
        'today': {'earnings': 0, 'pickups': 0, 'deliveries': 0},
        'week': {'earnings': 0, 'pickups': 0, 'deliveries': 0},
        'month': {'earnings': 0, 'pickups': 0, 'deliveries': 0},
        'days': [],
        'batches': [],
        'cod': {'in_hand': 0, 'limit': 5000, 'remitted_this_month': 0, 'pay_kept': 0},
        if (wallet != null) 'wallet': wallet,
      };

  test('the wallet from the earnings API: balance, this week, deductions and withdrawals', () {
    final e = EarningsData.fromJson(earnings(wallet: {
      'available': 40, 'awaiting_release': 240, 'pending_earned': 15, 'pending_deductions': 20, 'disputed': 100,
      'week_start': '2026-11-23', 'closes_at': '2026-11-29T23:59:59+08:00',
      'payout': {'method': 'gcash', 'account': '•••••••6543'},
      'deductions': [
        {'id': 7, 'kind': 'damage', 'label': 'Damaged parcel', 'amount': 100, 'reason': 'Broken mug', 'tracking_no': 'PR123',
         'at': '2026-11-21T12:00:00+08:00', 'status': 'disputed', 'dispute_reason': 'Already broken', 'can_dispute': false},
      ],
      'withdrawals': [
        {'id': 1, 'amount': 300, 'method': 'gcash', 'account': '•••••••6543', 'reference': 'SIM-261123-ABCDEFGH', 'status': 'paid',
         'at': '2026-11-23T08:00:00+08:00'},
      ],
    }));

    final w = e.wallet!;
    expect(w.available, 40.0);
    expect(w.awaitingRelease, 240.0);
    expect(w.thisWeekNet, -5.0);
    expect(w.payout!.label, 'GCash');
    expect(w.deductions.single.isDisputed, isTrue);
    expect(w.deductions.single.canDispute, isFalse);
    expect(w.withdrawals.single.reference, 'SIM-261123-ABCDEFGH');
    expect(EarningsData.fromJson(earnings()).wallet, isNull, reason: 'older servers send no wallet');
  });

  test('a payslip with its earnings and deductions', () {
    final p = Payslip.fromJson({
      'id': 3, 'week_start': '2026-11-16', 'week_end': '2026-11-22', 'pickups': 10, 'deliveries': 8, 'returns': 1,
      'earned': 360, 'deductions': 120, 'net': 240, 'status': 'released', 'released_at': '2026-11-23T09:00:00+08:00',
      'earnings': [
        {'kind': 'pickup', 'amount': 15, 'at': '2026-11-16T09:00:00+08:00', 'tracking_no': 'PR1', 'parcel_class': 'STANDARD'},
      ],
      'deduction_items': [
        {'id': 1, 'kind': 'shortage', 'label': 'Cash short', 'amount': 20, 'reason': 'Cash short', 'status': 'active', 'can_dispute': false},
      ],
    });

    expect(p.isReleased, isTrue);
    expect(p.net, 240.0);
    expect(p.weekEnd, DateTime(2026, 11, 22));
    expect(p.earnings.single.parcelClass, 'STANDARD');
    expect(p.deductionItems.single.kind, 'shortage');
  });
}
