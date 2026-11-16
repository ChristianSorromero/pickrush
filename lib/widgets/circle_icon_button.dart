import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/widgets/motion.dart';

/// Round bordered icon button (bell, back on full-screen flows). 44pt target.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.showBadge = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      enabled: onPressed != null,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            height: AppSize.minTap,
            width: AppSize.minTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 22, color: AppColors.textPrimary),
                Positioned(
                  top: 10,
                  right: 11,
                  child: AnimatedScale(
                    scale: showBadge ? 1 : 0,
                    duration: AppMotion.duration(context, AppMotion.small),
                    curve: AppMotion.enter,
                    child: Container(
                      height: 9,
                      width: 9,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
