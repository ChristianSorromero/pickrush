import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/models/dashboard_models.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/services/location_service.dart';

/// A batch as `/api/rider/batches/{id}` returns it: two stops, the first collected.
Map<String, dynamic> batchJson() => {
      'id': 3,
      'batch_no': 'PK-0003',
      'type': 'pickup',
      'status': 'accepted',
      'stage': 'pickup',
      'offered_at': '2026-10-24T09:00:00+08:00',
      'responded_at': '2026-10-24T09:02:00+08:00',
      'parcel_count': 3,
      'picked_count': 2,
      'dropped_off_count': 0,
      'est_earnings': 45,
      'drop_off': {'name': 'Tanauan City Station', 'address': 'City of Tanauan, Batangas'},
      'stops': [
        {
          'number': 1,
          'seller_name': 'Tote House',
          'seller_mobile': '09170000000',
          'address': 'Altura Bata, Tanauan',
          'status': 'picked_up',
          'parcel_count': 2,
          'picked_count': 2,
          'items': [
            {'assignment_id': 10, 'tracking_no': 'PR2610240000011A', 'description': 'Tote bag × 1', 'weight_kg': null, 'size': null, 'status': 'picked_up'},
            {'assignment_id': 11, 'tracking_no': 'PR2610240000012B', 'description': 'Tote bag × 2', 'weight_kg': 1.5, 'size': 'small', 'status': 'picked_up'},
          ],
        },
        {
          'number': 2,
          'seller_name': 'Kape Barako Co.',
          'seller_mobile': null,
          'address': 'Bagbag, Tanauan',
          'status': 'pending',
          'parcel_count': 1,
          'picked_count': 0,
          'items': [
            {'assignment_id': 12, 'tracking_no': 'PR2610240000013C', 'description': null, 'weight_kg': 2, 'size': null, 'status': 'to_pick'},
          ],
        },
      ],
    };

void main() {
  test('a batch from the API knows its next stop and what is left to pick', () {
    final b = RiderBatch.fromJson(batchJson());

    expect(b.batchNo, 'PK-0003');
    expect(b.status, BatchStatus.accepted);
    expect(b.stage, BatchStage.pickup);
    expect(b.isOffer, isFalse);
    expect(b.estEarnings, 45.0);
    expect(b.dropOff?.name, 'Tanauan City Station');
    expect(b.allPickedUp, isFalse);
    expect(b.nextStop?.sellerName, 'Kape Barako Co.');
    expect(b.nextStop?.toPick.single.assignmentId, 12);
    expect(b.stops.first.items[1].weightKg, 1.5);
  });

  test('pins, arrivals and item states come through for the trip and scanner screens', () {
    final json = batchJson();
    final stops = json['stops'] as List;
    (stops[0] as Map)
      ..['lat'] = 14.09
      ..['lng'] = 121.15;
    (stops[1] as Map)['arrived_at'] = '2026-10-24T10:40:00+08:00';
    (((stops[0] as Map)['items'] as List)[0] as Map)
      ..['status'] = 'received'
      ..['order_number'] = 'PS-882910';
    ((stops[1] as Map)['items'] as List).add({
      'assignment_id': 13, 'tracking_no': 'PR2610240000014D', 'order_number': null, 'description': null,
      'weight_kg': null, 'size': null, 'status': 'not_collected', 'note': 'Parcel not ready yet',
    });
    json['dropped_off_count'] = 1;
    json['drop_off'] = {
      'name': 'Tanauan City Station', 'address': 'J.P. Laurel Hwy', 'lat': null, 'lng': null,
      'arrived_at': null, 'manager': {'name': 'Paolo Santos', 'mobile': '09171112222'},
    };

    final b = RiderBatch.fromJson(json);
    expect(b.stops[0].pin?.lat, 14.09);
    expect(b.stops[1].pin, isNull);
    expect(b.stops[1].hasArrived, isTrue);
    expect(b.stops[0].items[0].status, ItemStatus.received);
    expect(b.stops[0].items[0].isPickedUp, isTrue);
    expect(b.stops[0].items[0].orderNumber, 'PS-882910');
    expect(b.stops[1].toPick.map((i) => i.trackingNo), ['PR2610240000013C'], reason: 'not-collected parcels are not scanned');
    expect(b.carrying, 1);
    expect(b.dropOff?.pin, isNull);
    expect(b.dropOff?.manager?.name, 'Paolo Santos');
    expect(b.collected.length, 2);
  });

  test('distance and ETA labels', () {
    expect(LocationService.distanceLabel(120.4), '120 m');
    expect(LocationService.distanceLabel(1240), '1.2 km');
    expect(LocationService.etaLabel(50), '1 min');
    expect(LocationService.eta(6800).inMinutes, greaterThan(20));
  });

  test('the dashboard parses today, batches and activity', () {
    final d = DashboardData.fromJson({
      'shift_status': 'on_shift',
      'hub': {'id': '4', 'name': 'Tanauan City Station', 'province': 'Batangas', 'city': 'City of Tanauan', 'address': null},
      'today': {'earnings': 30, 'pickups': 2, 'delivered': 0},
      'batches': [batchJson()..['status'] = 'offered'],
      'unread_notifications': 1,
      'activity': [
        {'type': 'dropped_off', 'title': 'Dropped off at Tanauan City Station', 'place': 'City of Tanauan', 'count': 2, 'at': DateTime.now().toIso8601String()},
      ],
    });

    expect(d.isOnline, isTrue);
    expect(d.todayEarnings, 30.0);
    expect(d.nextBatch?.isOffer, isTrue);
    expect(d.activity.single.type, ActivityType.arrived);
    expect(d.activity.single.title, 'Dropped off at Tanauan City Station · 2 parcels');
    expect(d.activity.single.subtitle, 'just now · City of Tanauan');
  });

  test('notifications point at their batch', () {
    final n = RiderNotification.fromJson({
      'id': 5,
      'type': 'pickup_offered',
      'title': 'New pickup batch #PK-0003',
      'body': '2 stops, 3 parcels: Tote House, Kape Barako Co.',
      'data': {'batch_id': 3},
      'read': false,
      'created_at': '2026-10-24T09:00:00+08:00',
    });
    expect(n.isNewPickup, isTrue);
    expect(n.batchId, 3);
  });

  test('a delivery batch from the API: loading, COD, returns and remittance', () {
    final b = RiderBatch.fromJson({
      'id': 9,
      'batch_no': 'DV-0009',
      'type': 'delivery',
      'status': 'accepted',
      'stage': 'deliver',
      'started_at': '2026-10-24T09:00:00+08:00',
      'parcel_count': 3,
      'loaded_count': 3,
      'delivered_count': 1,
      'failed_count': 1,
      'to_return_count': 1,
      'returned_count': 0,
      'cod_total': 1450,
      'cod_collected': 500,
      'to_remit': 500,
      'remitted': false,
      'est_earnings': 105,
      'arrival_radius_m': 150,
      'arrival_locked': false,
      'drop_off': {'name': 'Tanauan City Station', 'address': null, 'lat': 14.0863, 'lng': 121.1497, 'arrived_at': null, 'manager': null},
      'stops': [
        {
          'number': 1, 'kind': 'delivery', 'name': 'Ana Reyes', 'mobile': '09171234567', 'address': 'Altura Bata',
          'lat': null, 'lng': null, 'status': 'delivered', 'arrived_at': null, 'parcel_count': 1, 'cod_total': 500, 'earnings': 35,
          'items': [
            {'assignment_id': 1, 'kind': 'delivery', 'tracking_no': 'PRA', 'order_number': 'PS-1', 'description': null,
             'weight_kg': null, 'size': null, 'cod_amount': 500, 'status': 'delivered', 'note': null, 'done_at': '2026-10-24T10:00:00+08:00'},
          ],
        },
        {
          'number': 2, 'kind': 'delivery', 'name': 'Ben Cruz', 'mobile': null, 'address': 'Bagbag',
          'lat': null, 'lng': null, 'status': 'failed', 'arrived_at': null, 'parcel_count': 1, 'cod_total': 700, 'earnings': 35,
          'items': [
            {'assignment_id': 2, 'kind': 'delivery', 'tracking_no': 'PRB', 'order_number': null, 'description': null,
             'weight_kg': null, 'size': null, 'cod_amount': 700, 'status': 'failed', 'note': 'Buyer unavailable', 'done_at': null},
          ],
        },
        {
          'number': 3, 'kind': 'return', 'name': 'Tote House', 'mobile': null, 'address': 'Altura Bata',
          'lat': 14.09, 'lng': 121.15, 'status': 'pending', 'arrived_at': '2026-10-24T11:00:00+08:00', 'parcel_count': 1, 'cod_total': 0, 'earnings': 35,
          'items': [
            {'assignment_id': 3, 'kind': 'return', 'tracking_no': 'PRC', 'order_number': null, 'description': null,
             'weight_kg': null, 'size': null, 'cod_amount': 0, 'status': 'out_for_delivery', 'note': null, 'done_at': null},
          ],
        },
      ],
    });

    expect(b.isDelivery, isTrue);
    expect(b.hasStarted, isTrue);
    expect(b.stage, BatchStage.deliver);
    expect(b.allStopsDone, isFalse);
    expect(b.nextStop?.name, 'Tote House');
    expect(b.nextStop?.isReturn, isTrue);
    expect(b.nextStop?.toDeliver.single.trackingNo, 'PRC');
    expect(b.nextStop?.open.single.assignmentId, 3);
    expect(b.nextStop?.pin?.lat, 14.09);
    expect(b.stops.first.items.single.reference, '#PS-1');
    expect(b.returns.single.status, ItemStatus.failed);
    expect(b.toRemit, 500.0);
    expect(b.remitted, isFalse);
  });

  test('time ago reads naturally', () {
    final now = DateTime(2026, 10, 24, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 20)), now), 'just now');
    expect(timeAgo(now.subtract(const Duration(minutes: 1)), now), '1 min ago');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now), '3 hours ago');
  });
}
