import 'package:rider_app/models/dashboard_models.dart';

/// Hardcoded data. Replace with a repository/API later.
class DashboardMockData {
  DashboardMockData._();

  static const summary = DashboardSummary(
    isOnline: true,
    hubName: 'QC Sorting Center',
    todayEarnings: 1450,
    pickups: 5,
    delivered: 12,
    hasUnreadNotifications: true,
  );

  static const recentActivity = [
    ActivityItem(
      type: ActivityType.delivered,
      title: 'Order #PX-9921 Delivered',
      subtitle: '2 mins ago · Metro Manila',
    ),
    ActivityItem(
      type: ActivityType.pickupConfirmed,
      title: 'Pickup at Tindahan ni Rosa Confirmed',
      subtitle: '15 mins ago · Quezon City',
    ),
    ActivityItem(
      type: ActivityType.arrived,
      title: 'Arrived at Sorting Center',
      subtitle: '1 hour ago · Valenzuela Hub',
    ),
  ];
}
