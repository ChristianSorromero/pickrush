import 'package:flutter/material.dart';

import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';

class EarningsHeader extends StatelessWidget {
  const EarningsHeader({super.key, required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("TODAY'S EARNINGS", style: AppTextStyles.overline),
        const SizedBox(height: 4),
        Text(FormatUtils.peso(amount), style: AppTextStyles.display),
      ],
    );
  }
}
