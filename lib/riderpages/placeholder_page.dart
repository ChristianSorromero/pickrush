import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_text_styles.dart';

/// Temporary screen for tabs we haven't designed yet.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(
          '$title (coming soon)',
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}
