import 'package:dio/dio.dart';
import 'package:rider_app/models/dashboard_models.dart';
import 'package:rider_app/models/earnings_models.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/services/api_client.dart';
import 'package:rider_app/services/location_service.dart';

class TaskException implements Exception {
  TaskException(this.message, {this.signedOut = false});
  final String message;

  /// The token is no longer valid (401) or the account is no longer active (403).
  final bool signedOut;

  @override
  String toString() => message;
}

/// A parcel the seller could not hand over, and why.
class NotCollected {
  const NotCollected(this.trackingNo, this.reason, [this.note]);
  final String trackingNo;
  final String reason;
  final String? note;

  Map<String, dynamic> toJson() => {
        'tracking_no': trackingNo,
        'reason': reason,
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}

/// What the station sends the rider changed since the last poll.
class Pulse {
  const Pulse({
    required this.unreadNotifications,
    required this.offeredBatchIds,
    this.offeredDeliveryIds = const [],
    this.latest,
  });

  final int unreadNotifications;
  final List<int> offeredBatchIds;

  /// The offers that are delivery batches (the rest are pickups).
  final List<int> offeredDeliveryIds;
  final RiderNotification? latest;
}

/// The rider's work from Picksell's rider API: home, pickup batches,
/// notifications and going online/offline.
class RiderTaskService {
  Future<DashboardData> dashboard() => _call(() async {
        final res = await apiClient.get('/api/rider/dashboard');
        return DashboardData.fromJson(_map(res.data));
      });

  Future<Pulse> pulse() => _call(() async {
        final j = _map((await apiClient.get('/api/rider/pulse')).data);
        return Pulse(
          unreadNotifications: j['unread_notifications'] as int,
          offeredBatchIds: [for (final id in j['offered_batch_ids'] as List) id as int],
          offeredDeliveryIds: [for (final id in (j['offered_delivery_ids'] as List? ?? const [])) id as int],
          latest: j['latest_notification'] is Map
              ? RiderNotification.fromJson(_map(j['latest_notification']))
              : null,
        );
      });

  Future<List<RiderBatch>> batches() => _call(() async {
        final res = await apiClient.get('/api/rider/batches');
        return [
          for (final b in _map(res.data)['batches'] as List)
            RiderBatch.fromJson(_map(b)),
        ];
      });

  Future<RiderBatch> batch(int id) =>
      _call(() async => _batch(await apiClient.get('/api/rider/batches/$id')));

  Future<RiderBatch> accept(int id) => _call(
      () async => _batch(await apiClient.post('/api/rider/batches/$id/accept')));

  Future<RiderBatch> decline(int id, {String? reason}) => _call(() async =>
      _batch(await apiClient.post('/api/rider/batches/$id/decline',
          data: {if (reason != null && reason.isNotEmpty) 'reason': reason})));

  /// Waybills scanned at a stop, plus the ones the seller could not hand over
  /// (they go back to the station). [requestKey] makes a retry safe.
  Future<RiderBatch> confirmPickup(
    int batchId, {
    required List<String> trackingNos,
    List<NotCollected> notCollected = const [],
    required String requestKey,
  }) =>
      _call(() async => _batch(await apiClient.post(
            '/api/rider/batches/$batchId/pickups',
            data: {
              'tracking_nos': trackingNos,
              if (notCollected.isNotEmpty)
                'not_collected': [for (final n in notCollected) n.toJson()],
              'request_key': requestKey,
            },
          )));

  /// "Arrived at stop": refused by the server when the shop is pinned and
  /// the rider is too far from it.
  Future<RiderBatch> arriveAtStop(int batchId, List<int> assignmentIds, GpsFix fix) =>
      _call(() async => _batch(await apiClient.post(
            '/api/rider/batches/$batchId/stops/arrive',
            data: {'assignment_ids': assignmentIds, ...fix.toJson()},
          )));

  Future<RiderBatch> arriveAtHub(int batchId, GpsFix fix) => _call(() async =>
      _batch(await apiClient.post('/api/rider/batches/$batchId/hub/arrive',
          data: fix.toJson())));

  // Delivery batches ------------------------------------------------------------

  /// One parcel scanned onto the vehicle at the station.
  Future<RiderBatch> load(int batchId, String trackingNo) => _call(() async =>
      _batch(await apiClient.post('/api/rider/batches/$batchId/load',
          data: {'tracking_no': trackingNo})));

  /// Leave the station; parcels not scanned need [leaveBehindReason].
  Future<RiderBatch> startRoute(int batchId,
          {String? leaveBehindReason, required String requestKey}) =>
      _call(() async => _batch(await apiClient.post(
            '/api/rider/batches/$batchId/start',
            data: {
              if (leaveBehindReason != null) 'leave_behind_reason': leaveBehindReason,
              'request_key': requestKey,
            },
          )));

  /// Handed over at the door: the scanned waybill, the COD collected and a photo.
  Future<RiderBatch> deliver(
    int batchId,
    int assignmentId, {
    required String trackingNo,
    required double codConfirmed,
    required String photoPath,
    required String requestKey,
  }) =>
      _call(() async => _batch(await apiClient.post(
            '/api/rider/batches/$batchId/deliveries/$assignmentId/deliver',
            data: FormData.fromMap({
              'tracking_no': trackingNo,
              'cod_confirmed': codConfirmed.toStringAsFixed(2),
              'photo': await MultipartFile.fromFile(photoPath, filename: 'proof.jpg'),
              'request_key': requestKey,
            }),
          )));

  /// A failed attempt: a reason (a note for "other") and a photo of the place.
  Future<RiderBatch> failDelivery(
    int batchId,
    int assignmentId, {
    required String reason,
    String? note,
    required String photoPath,
    required String requestKey,
  }) =>
      _call(() async => _batch(await apiClient.post(
            '/api/rider/batches/$batchId/deliveries/$assignmentId/fail',
            data: FormData.fromMap({
              'reason': reason,
              if (note != null && note.isNotEmpty) 'note': note,
              'photo': await MultipartFile.fromFile(photoPath, filename: 'attempt.jpg'),
              'request_key': requestKey,
            }),
          )));

  /// "Report a problem": shows up on the station dashboard.
  Future<void> reportProblem(int batchId,
          {required String type, String? note, GpsFix? fix}) =>
      _call(() async {
        await apiClient.post('/api/rider/batches/$batchId/reports', data: {
          'type': type,
          if (note != null && note.isNotEmpty) 'note': note,
          if (fix != null) 'lat': fix.lat,
          if (fix != null) 'lng': fix.lng,
        });
      });

  RiderOptions? _options;

  /// Reasons and problem types (cached for the session).
  Future<RiderOptions> options() async {
    final cached = _options;
    if (cached != null) return cached;
    final fresh = await _call(() async =>
        RiderOptions.fromJson(_map((await apiClient.get('/api/rider/options')).data)));
    return _options = fresh;
  }

  Future<EarningsData> earnings() => _call(() async =>
      EarningsData.fromJson(_map((await apiClient.get('/api/rider/earnings')).data)));

  Future<List<RiderNotification>> notifications() => _call(() async {
        final res = await apiClient.get('/api/rider/notifications');
        return [
          for (final n in _map(res.data)['notifications'] as List)
            RiderNotification.fromJson(_map(n)),
        ];
      });

  Future<void> markNotificationsRead([List<int>? ids]) => _call(() async {
        await apiClient.post('/api/rider/notifications/read',
            data: {if (ids != null) 'ids': ids});
      });

  /// Returns true when the rider is now online (on shift).
  Future<bool> setOnline(bool online) => _call(() async {
        final res = await apiClient.patch('/api/rider/shift',
            data: {'shift_status': online ? 'on_shift' : 'off_duty'});
        return _map(res.data)['shift_status'] == 'on_shift';
      });

  static RiderBatch _batch(Response res) =>
      RiderBatch.fromJson(_map(_map(res.data)['batch']));

  static Map<String, dynamic> _map(Object? data) =>
      Map<String, dynamic>.from(data as Map);

  static Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      throw TaskException(apiErrorMessage(e),
          signedOut: code == 401 || code == 403);
    }
  }
}

final RiderTaskService riderTasks = RiderTaskService();
