import 'package:flutter/material.dart';

import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/widgets/section_header.dart';
import 'package:rider_app/services/dashboard_mock_data.dart';
import 'package:rider_app/widgets/activity_timeline.dart';
import 'package:rider_app/widgets/dashboard_top_bar.dart';
import 'package:rider_app/widgets/earnings_header.dart';
import 'package:rider_app/widgets/next_assignment_card.dart';
import 'package:rider_app/widgets/stats_row.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const summary = DashboardMockData.summary;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardTopBar(
              isOnline: summary.isOnline,
              hubName: summary.hubName,
              hasNotifications: summary.hasUnreadNotifications,
            ),
            AppSpacing.gapXl,
            EarningsHeader(amount: summary.todayEarnings),
            AppSpacing.gapLg,
            StatsRow(pickups: summary.pickups, delivered: summary.delivered),
            AppSpacing.gapXxl,
            const SectionHeader(title: 'Next Assignment'),
            AppSpacing.gapMd,
            const NextAssignmentCard(), // empty state for now
            AppSpacing.gapXxl,
            SectionHeader(
              title: 'Recent Activity',
              actionLabel: 'View All',
              onActionTap: () {},
            ),
            AppSpacing.gapMd,
            const ActivityTimeline(items: DashboardMockData.recentActivity),
            AppSpacing.gapLg,
          ],
        ),
      ),
    );
  }
}
