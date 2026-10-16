import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/widgets/surface_card.dart';

/// Empty state for now. Add an `assignment` param when the design arrives.
class NextAssignmentCard extends StatelessWidget {
  const NextAssignmentCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      height: 150,
      child: Center(
        child: Text(
          'no assignment yet',
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}
