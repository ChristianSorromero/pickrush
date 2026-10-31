import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_text_styles.dart';

/// The password rule the server enforces, checked as the rider types.
class PasswordRules {
  PasswordRules(this.text);
  final String text;

  bool get length => text.length >= 8;
  /// Upper- and lower-case letters (the server asks for both).
  bool get uppercase => text.contains(RegExp(r'[A-Z]')) && text.contains(RegExp(r'[a-z]'));
  bool get number => text.contains(RegExp(r'[0-9]'));
  bool get special => text.contains(RegExp(r'[^A-Za-z0-9]'));
  bool get allMet => length && uppercase && number && special;
}

class PasswordRuleList extends StatelessWidget {
  const PasswordRuleList({super.key, required this.rules});
  final PasswordRules rules;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RuleItem('8+ characters', rules.length),
              const SizedBox(height: 6),
              _RuleItem('One number', rules.number),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RuleItem('Upper & lowercase', rules.uppercase),
              const SizedBox(height: 6),
              _RuleItem('Special character', rules.special),
            ],
          ),
        ),
      ],
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem(this.label, this.met);
  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 14,
          color: met ? AppColors.success : AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: met ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
