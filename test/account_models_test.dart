import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/models/earnings_models.dart';
import 'package:rider_app/services/auth_service.dart';

void main() {
  test('earnings from the API: periods, the 7-day chart, batches and COD', () {
    final e = EarningsData.fromJson({
      'rates': {'pickup': 15, 'delivery': 35},
      'today': {'earnings': 65, 'pickups': 2, 'deliveries': 1},
      'week': {'earnings': 100, 'pickups': 2, 'deliveries': 2},
      'month': {'earnings': 100.5, 'pickups': 2, 'deliveries': 2},
      'days': [
        for (var i = 6; i >= 0; i--)
          {'date': DateTime(2026, 10, 25).subtract(Duration(days: i)).toIso8601String().substring(0, 10),
           'earnings': i == 0 ? 65 : 0, 'pickups': i == 0 ? 2 : 0, 'deliveries': i == 0 ? 1 : 0},
      ],
      'batches': [
        {'id': 3, 'batch_no': 'DV-0003', 'type': 'delivery', 'completed_at': '2026-10-25T10:00:00+08:00', 'parcels': 1, 'earned': 35},
      ],
      'cod': {
        'in_hand': 650, 'limit': 5000, 'remitted_this_month': 300,
        'last_remittance': {'amount': 300, 'at': '2026-10-24T18:00:00+08:00', 'status': 'reconciled'},
      },
    });

    expect(e.pickupRate, 15.0);
    expect(e.today.earnings, 65.0);
    expect(e.month.earnings, 100.5);
    expect(e.days, hasLength(7));
    expect(e.days.last.date, DateTime(2026, 10, 25));
    expect(e.batches.single.isDelivery, isTrue);
    expect(e.cod.inHand, 650.0);
    expect(e.cod.lastStatus, 'reconciled');
  });

  test('the account reads station details, masked payout and document expiry', () {
    final a = RiderAccount.fromJson({
      'id': 3, 'status': 'active', 'full_name': 'Xtian Sorro', 'email': 'x@r.test', 'mobile': '9181234567',
      'shift_status': 'on_shift', 'on_probation': true, 'zone': 'Zone A', 'cod_limit': 5000, 'max_parcels': 20,
      'street': '12 Rizal St', 'barangay': {'code': '1', 'name': 'Altura Bata'}, 'city': {'code': '2', 'name': 'City of Tanauan'},
      'province': {'code': '3', 'name': 'Batangas'},
      'payout': {'method': 'gcash', 'account': '•••••••6543'},
      'station_contact': {'name': 'Paolo Santos', 'mobile': '09171112222'},
      'documents': [
        {'type': 'drivers_license', 'label': "Driver's license", 'side': 'front', 'expiry': '2026-11-14'},
      ],
    });

    expect(a.isOnline, isTrue);
    expect(a.onProbation, isTrue);
    expect(a.fullAddress, '12 Rizal St, Altura Bata, City of Tanauan, Batangas');
    expect(a.payout?.account, '•••••••6543');
    expect(a.stationContact?.name, 'Paolo Santos');
    expect(a.documents.single.title, "Driver's license (Front)");
    expect(a.documents.single.daysLeft(DateTime(2026, 10, 25)), 20);
  });
}
