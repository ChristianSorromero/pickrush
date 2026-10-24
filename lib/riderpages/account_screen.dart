import 'package:flutter/material.dart';
import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/riderpages/login.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/auth_service.dart';
import 'package:rider_app/widgets/app_button.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    assignmentWatcher.reset();
    await authService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account', style: AppTextStyles.h1),
            AppSpacing.gapXl,
            // Profile row
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primarySoft,
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.primary, size: 30),
                ),
                AppSpacing.gapMd,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rider Name', style: AppTextStyles.h2),
                    Text('rider@company.com',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
            const Spacer(),
            const Divider(color: AppColors.border, height: 1),
            AppSpacing.gapLg,
            AppButton(
              label: 'Log Out',
              onPressed: () => _logout(context),
            ),
            AppSpacing.gapMd,
          ],
        ),
      ),
    );
  }
}
