import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/widgets/circle_icon_button.dart';
import 'package:rider_app/widgets/motion.dart';

/// Today's header: the station, the duty switch (ONLINE / OFFLINE), the bell.
class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.isOnline,
    required this.hubName,
    required this.hasNotifications,
    this.switching = false,
    this.onToggleOnline,
    this.onNotifications,
  });

  final bool isOnline;
  final String hubName;
  final bool hasNotifications;

  /// The duty change is being sent.
  final bool switching;

  /// Tapping the duty switch.
  final VoidCallback? onToggleOnline;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text('Today', style: AppTextStyles.h1)),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.warehouse_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(hubName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _DutySwitch(online: isOnline, busy: switching, onTap: onToggleOnline),
        const SizedBox(width: AppSpacing.sm),
        CircleIconButton(
          icon: Icons.notifications_none_rounded,
          showBadge: hasNotifications,
          onPressed: onNotifications,
        ),
      ],
    );
  }
}

class _DutySwitch extends StatelessWidget {
  const _DutySwitch({required this.online, required this.busy, this.onTap});

  final bool online;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = AppMotion.duration(context, AppMotion.small);
    final color = online ? AppColors.success : AppColors.textMuted;
    return Semantics(
      button: true,
      toggled: online,
      label: online ? 'On duty, online. Tap to go offline' : 'Off duty, offline. Tap to go online',
      excludeSemantics: true,
      child: Pressable(
        enabled: !busy,
        child: Material(
          color: online ? AppColors.successSoft : AppColors.surface,
          shape: StadiumBorder(side: BorderSide(color: online ? AppColors.success.withValues(alpha: 0.35) : AppColors.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: busy ? null : onTap,
            child: AnimatedContainer(
              duration: d,
              height: AppSize.minTap,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                  else
                    AnimatedContainer(
                      duration: d,
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  const SizedBox(width: 8),
                  Text(online ? 'Online' : 'Offline', style: AppTextStyles.label.copyWith(color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
