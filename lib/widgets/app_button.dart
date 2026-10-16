import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';

enum AppButtonVariant { primary, outline }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: AppRadius.pillAll);
    final isPrimary = variant == AppButtonVariant.primary;
    // Primary buttons use white text on coral (per the login mockup).
    final fg = isPrimary ? AppColors.surface : AppColors.textPrimary;

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Text(label, style: AppTextStyles.button.copyWith(color: fg));

    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: fg,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
            elevation: 0,
            shape: shape,
          ),
          child: child,
        ),
      AppButtonVariant.outline => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            shape: shape,
          ),
          child: child,
        ),
    };

    return SizedBox(
      height: 52,
      width: expand ? double.infinity : null,
      child: button,
    );
  }
}