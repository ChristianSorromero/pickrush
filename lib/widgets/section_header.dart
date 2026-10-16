import 'package:flutter/material.dart';

import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/widgets/app_link_button.dart';

/// "Next Assignment" / "Recent Activity  View All" style header.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.h2),
        if (actionLabel != null)
          AppLinkButton(label: actionLabel!, onPressed: onActionTap),
      ],
    );
  }
}
