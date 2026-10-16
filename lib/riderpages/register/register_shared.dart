import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'register_data.dart';

export 'register_data.dart';

// ── Scaffold ──────────────────────────────────────────────────────────────────

class RegisterStepScaffold extends StatelessWidget {
  const RegisterStepScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    required this.buttonLabel,
    required this.onContinue,
    this.onBack,
    this.isLoading = false,
    this.totalSteps = kRegisterTotalSteps,
  });

  final int step;
  final int totalSteps;
  final String title;
  final Widget child;
  final String buttonLabel;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _BackButton(onPressed: onBack),
                      AppSpacing.gapMd,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STEP $step OF $totalSteps',
                            style: AppTextStyles.overline.copyWith(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(title,
                              style: AppTextStyles.h2.copyWith(fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                  AppSpacing.gapMd,
                  _StepProgress(current: step, total: totalSteps),
                  AppSpacing.gapLg,
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH),
                child: child,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                  AppSpacing.md, AppSpacing.screenH, AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: AppButton(
                label: buttonLabel,
                onPressed: onContinue,
                isLoading: isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          height: 40,
          width: 40,
          child: Icon(Icons.arrow_back_rounded,
              size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < current;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.border,
              borderRadius: AppRadius.pillAll,
            ),
          ),
        );
      }),
    );
  }
}

// ── Shared form widgets ───────────────────────────────────────────────────────

class RegisterLabeledField extends StatelessWidget {
  const RegisterLabeledField(
      {super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.overline.copyWith(
            fontSize: 11,
            color: AppColors.textPrimary,
          ),
        ),
        AppSpacing.gapSm,
        child,
      ],
    );
  }
}

class RegisterSectionHeader extends StatelessWidget {
  const RegisterSectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: AppTextStyles.overline.copyWith(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        AppSpacing.gapSm,
        const Divider(color: AppColors.border, height: 1),
      ],
    );
  }
}

class RegisterErrorBanner extends StatelessWidget {
  const RegisterErrorBanner(
      {super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text('Retry', style: AppTextStyles.link),
            ),
        ],
      ),
    );
  }
}

class RegisterDropdown<T> extends StatelessWidget {
  const RegisterDropdown({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.isLoading = false,
    this.isRequired = true,
  });

  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?>? onChanged;
  final bool isLoading;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      icon: isLoading
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
          : const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
      style: AppTextStyles.bodyStrong,
      dropdownColor: AppColors.surface,
      borderRadius: AppRadius.mdAll,
      decoration: registerInputDecoration(hint),
      hint: Text(isLoading ? 'Loading…' : hint,
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
      items: items
          .map((e) => DropdownMenuItem<T>(
                value: e,
                child: Text(labelOf(e), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: isLoading ? null : onChanged,
      validator: isRequired ? (v) => v == null ? 'Required' : null : null,
    );
  }
}

// ── Input decoration helpers ──────────────────────────────────────────────────

OutlineInputBorder registerBorder([Color color = AppColors.border]) =>
    OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: BorderSide(color: color),
    );

InputDecoration registerInputDecoration(String hint, {Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
    filled: true,
    fillColor: AppColors.surface,
    suffixIcon: suffixIcon,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: registerBorder(),
    enabledBorder: registerBorder(),
    disabledBorder: registerBorder(),
    focusedBorder: registerBorder(AppColors.primary),
    errorBorder: registerBorder(AppColors.primaryDark),
    focusedErrorBorder: registerBorder(AppColors.primaryDark),
    errorStyle:
        AppTextStyles.caption.copyWith(color: AppColors.primaryDark),
  );
}

const registerMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String formatRegisterDate(DateTime d) =>
    '${registerMonths[d.month - 1]} ${d.day}, ${d.year}';
