import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';

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
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.textPrimary),
            if (showBadge)
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  height: 7,
                  width: 7,
                  decoration: const BoxDecoration(
                      color: AppColors.primaryDark, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
