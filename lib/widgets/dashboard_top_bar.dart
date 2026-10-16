import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/widgets/circle_icon_button.dart';
import 'package:rider_app/widgets/status_pill.dart';

class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.isOnline,
    required this.hubName,
    required this.hasNotifications,
  });

  final bool isOnline;
  final String hubName;
  final bool hasNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StatusPill.dot(
          label: isOnline ? 'ONLINE' : 'OFFLINE',
          color: isOnline ? AppColors.success : AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: StatusPill.icon(label: hubName, icon: Icons.apartment_rounded),
        ),
        const Spacer(),
        CircleIconButton(
          icon: Icons.notifications_none_rounded,
          showBadge: hasNotifications,
          onPressed: () {},
        ),
      ],
    );
  }
}
