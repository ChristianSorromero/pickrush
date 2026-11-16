import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/widgets/motion.dart';

enum AppButtonVariant { primary, outline, destructive }

/// The one main action of a screen (primary), or a supporting one (outline).
/// While [isLoading] it shows a spinner and ignores taps, so a confirmation
/// can't be sent twice; the press reacts at once and never delays the call.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.expand = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final (bg, fg, side) = switch (variant) {
      AppButtonVariant.primary => (AppColors.primary, AppColors.onPrimary, BorderSide.none),
      AppButtonVariant.outline => (AppColors.surface, AppColors.textPrimary, const BorderSide(color: AppColors.border)),
      AppButtonVariant.destructive => (
          AppColors.surface,
          AppColors.errorStrong,
          const BorderSide(color: AppColors.error, width: 1.4)
        ),
    };

    final body = isLoading
        ? SizedBox(
            key: const ValueKey('loading'),
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            key: const ValueKey('label'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(
                  child: Text(label, overflow: TextOverflow.ellipsis, style: AppTextStyles.button.copyWith(color: fg))),
            ],
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        enabled: enabled,
        child: SizedBox(
          height: AppSize.buttonHeight,
          width: expand ? double.infinity : null,
          child: ElevatedButton(
            // While loading keep the colors (not the disabled grey) but drop taps.
            onPressed: enabled ? onPressed : (isLoading ? () {} : null),
            style: ElevatedButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              disabledBackgroundColor: variant == AppButtonVariant.primary ? AppColors.border : AppColors.surface,
              disabledForegroundColor: AppColors.textMuted,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              side: side,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.duration(context, AppMotion.icon),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
