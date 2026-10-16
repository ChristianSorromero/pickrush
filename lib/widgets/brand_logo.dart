import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:rider_app/app_assets.dart';
import 'package:rider_app/app_colors.dart';

/// "P" mark + "ICKRUSH" wordmark (the P doubles as the first letter).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 56});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Image.asset(AppAssets.logoMark, height: height),
        Transform.translate(
          offset: Offset(-height * 0.08, -height * 0.02),
          child: Text(
            'ICKRUSH',
            style: GoogleFonts.montserrat(
              fontSize: height * 0.42,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
