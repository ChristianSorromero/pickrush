enum ActivityType { delivered, pickupConfirmed, arrived }

class ActivityItem {
  const ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
  });

  final ActivityType type;
  final String title;
  final String subtitle;
}

class DashboardSummary {
  const DashboardSummary({
    required this.isOnline,
    required this.hubName,
    required this.todayEarnings,
    required this.pickups,
    required this.delivered,
    required this.hasUnreadNotifications,
  });

  final bool isOnline;
  final String hubName;
  final double todayEarnings;
  final int pickups;
  final int delivered;
  final bool hasUnreadNotifications;
}
