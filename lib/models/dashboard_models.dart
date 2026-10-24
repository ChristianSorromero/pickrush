import 'package:rider_app/models/batch_models.dart';

enum ActivityType {
  delivered,
  pickupConfirmed,
  arrived,
  outForDelivery,
  failed;

  static ActivityType parse(String? v) => switch (v) {
        'pickup' => ActivityType.pickupConfirmed,
        'dropped_off' => ActivityType.arrived,
        'out_for_delivery' => ActivityType.outForDelivery,
        'failed' => ActivityType.failed,
        _ => ActivityType.delivered,
      };
}

class ActivityItem {
  const ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
  });

  final ActivityType type;
  final String title;
  final String subtitle;

  /// One line of `activity` from `/api/rider/dashboard`.
  factory ActivityItem.fromJson(Map<String, dynamic> j) {
    final count = (j['count'] as int?) ?? 1;
    final at = DateTime.tryParse(j['at'] as String? ?? '')?.toLocal();
    final place = j['place'] as String?;
    return ActivityItem(
      type: ActivityType.parse(j['type'] as String?),
      title: count > 1 ? '${j['title']} · $count parcels' : j['title'] as String,
      subtitle: [
        if (at != null) timeAgo(at),
        if (place != null && place.isNotEmpty) place,
      ].join(' · '),
    );
  }
}

/// "just now", "5 mins ago", "2 hours ago", "3 days ago".
String timeAgo(DateTime at, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(at);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min${d.inMinutes == 1 ? '' : 's'} ago';
  if (d.inHours < 24) return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
  return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
}

class RiderHub {
  const RiderHub({required this.name, this.city});
  final String name;
  final String? city;
}

/// Everything the home screen shows, from `/api/rider/dashboard`.
class DashboardData {
  const DashboardData({
    required this.isOnline,
    required this.todayEarnings,
    required this.pickups,
    required this.delivered,
    required this.batches,
    required this.unreadNotifications,
    required this.activity,
    this.hub,
  });

  final bool isOnline;
  final RiderHub? hub;
  final double todayEarnings;
  final int pickups;
  final int delivered;

  /// Open batches: offers waiting for an answer first, then ones in progress.
  final List<RiderBatch> batches;
  final int unreadNotifications;
  final List<ActivityItem> activity;

  RiderBatch? get nextBatch => batches.isEmpty ? null : batches.first;

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    final today = Map<String, dynamic>.from(j['today'] as Map);
    final hub = j['hub'] is Map ? Map<String, dynamic>.from(j['hub'] as Map) : null;
    return DashboardData(
      isOnline: j['shift_status'] == 'on_shift',
      hub: hub == null
          ? null
          : RiderHub(name: hub['name'] as String, city: hub['city'] as String?),
      todayEarnings: (today['earnings'] as num).toDouble(),
      pickups: today['pickups'] as int,
      delivered: today['delivered'] as int,
      batches: [
        for (final b in j['batches'] as List)
          RiderBatch.fromJson(Map<String, dynamic>.from(b as Map)),
      ],
      unreadNotifications: j['unread_notifications'] as int,
      activity: [
        for (final a in j['activity'] as List)
          ActivityItem.fromJson(Map<String, dynamic>.from(a as Map)),
      ],
    );
  }
}

class RiderNotification {
  const RiderNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.isRead,
    required this.createdAt,
    this.body,
    this.batchId,
  });

  final int id;
  final String type;
  final String title;
  final String? body;
  final int? batchId;
  final bool isRead;
  final DateTime createdAt;

  bool get isNewPickup => type == 'pickup_offered';

  /// A new batch to accept (pickup or delivery).
  bool get isOffer => type == 'pickup_offered' || type == 'delivery_offered';

  factory RiderNotification.fromJson(Map<String, dynamic> j) {
    final data = j['data'] is Map ? j['data'] as Map : const {};
    return RiderNotification(
      id: j['id'] as int,
      type: j['type'] as String,
      title: j['title'] as String,
      body: j['body'] as String?,
      batchId: data['batch_id'] as int?,
      isRead: j['read'] as bool? ?? false,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    );
  }
}
