import 'package:flutter/material.dart';

import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/riderpages/notifications_screen.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/widgets/circle_icon_button.dart';

/// The bell on every tab: a dot while something is unread, opens the
/// notification list. Reads the unread count from [assignmentWatcher].
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.onClosed});

  /// After the list closes (e.g. to reload the tab).
  final VoidCallback? onClosed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: assignmentWatcher,
      builder: (context, _) => Semantics(
        label: assignmentWatcher.unreadNotifications > 0 ? 'Notifications, unread' : 'Notifications',
        child: CircleIconButton(
          icon: Icons.notifications_none_rounded,
          showBadge: assignmentWatcher.unreadNotifications > 0,
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            onClosed?.call();
          },
        ),
      ),
    );
  }
}

/// Title row of a top-level tab: title, optional subtitle, and the bell.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.subtitle, this.onNotificationsClosed});

  final String title;
  final String? subtitle;
  final VoidCallback? onNotificationsClosed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: AppTextStyles.h1)),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: AppTextStyles.body),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        NotificationBell(onClosed: onNotificationsClosed),
      ],
    );
  }
}
