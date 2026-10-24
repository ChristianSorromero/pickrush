import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/riderpages/login.dart';
import 'package:rider_app/riderpages/main_shell.dart';
import 'package:rider_app/riderpages/register/register.dart';
import 'package:rider_app/services/auth_service.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/brand_logo.dart';

/// What a signed-in rider sees until the station approves them: pending,
/// rejected (with the reason and a way to resubmit) or suspended. Nothing
/// else in the app opens until the account is active.
class ApplicationStatusScreen extends StatefulWidget {
  const ApplicationStatusScreen({super.key, this.account});

  /// Already loaded (e.g. right after login); otherwise fetched here.
  final RiderAccount? account;

  @override
  State<ApplicationStatusScreen> createState() =>
      _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  late RiderAccount? _account = widget.account;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_account == null) _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await authService.me();
      if (!mounted) return;
      if (account.status == RiderStatus.active) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (_) => false,
        );
        return;
      }
      setState(() => _account = account);
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.signedOut) return _toLogin();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await authService.logout();
    if (mounted) _toLogin();
  }

  void _toLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _resubmit() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          RegisterScreen(initial: RegisterData.resubmission(_account!)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
            children: [
              Row(
                children: [
                  const BrandLogo(),
                  const Spacer(),
                  TextButton(
                    onPressed: _logout,
                    child: Text('Log out', style: AppTextStyles.link),
                  ),
                ],
              ),
              AppSpacing.gapXl,
              if (account == null)
                _loading
                    ? const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        ),
                      )
                    : _ErrorCard(
                        message: _error ?? 'Could not load your status.',
                        onRetry: _refresh)
              else ...[
                _StatusCard(account: account),
                if (_error != null) ...[
                  AppSpacing.gapLg,
                  _ErrorCard(message: _error!, onRetry: _refresh),
                ],
                AppSpacing.gapXl,
                if (account.status == RiderStatus.rejected)
                  AppButton(
                      label: 'Fix and Resubmit Application',
                      onPressed: _resubmit)
                else
                  AppButton(
                    label: 'Check Status',
                    isLoading: _loading,
                    onPressed: _loading ? null : _refresh,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.account});
  final RiderAccount account;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, body) = switch (account.status) {
      RiderStatus.rejected => (
          Icons.error_rounded,
          AppColors.primaryDark,
          'Application not approved',
          'Your station could not approve your application. Fix what '
              'they asked for below and resubmit.',
        ),
      RiderStatus.suspended => (
          Icons.pause_circle_filled_rounded,
          AppColors.primaryDark,
          'Account suspended',
          'You cannot receive parcels for now. Please contact your station.',
        ),
      _ => (
          Icons.hourglass_top_rounded,
          AppColors.primary,
          'Application under review',
          'Your station hub manager is reviewing your documents and may '
              'call you for an interview. You will get parcels once you are '
              'approved.',
        ),
    };
    final station = account.station;
    final applied = account.appliedAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          AppSpacing.gapLg,
          Text(title, style: AppTextStyles.h2.copyWith(fontSize: 20)),
          AppSpacing.gapSm,
          Text(body,
              style: AppTextStyles.body.copyWith(fontSize: 13, height: 1.5)),
          if (account.statusReason != null &&
              account.statusReason!.isNotEmpty) ...[
            AppSpacing.gapLg,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: AppRadius.mdAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REASON FROM YOUR STATION',
                      style: AppTextStyles.overline.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark)),
                  const SizedBox(height: 4),
                  Text(account.statusReason!,
                      style: AppTextStyles.bodyStrong.copyWith(fontSize: 13)),
                ],
              ),
            ),
          ],
          AppSpacing.gapLg,
          const Divider(color: AppColors.border, height: 1),
          AppSpacing.gapMd,
          _Row('Name', account.fullName),
          _Row('Station', station?.name ?? '—'),
          if (applied != null)
            _Row('Applied',
                '${applied.year}-${applied.month.toString().padLeft(2, '0')}-${applied.day.toString().padLeft(2, '0')}'),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label.toUpperCase(),
                style: AppTextStyles.overline.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

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
            child: Text(message,
                style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry', style: AppTextStyles.link),
          ),
        ],
      ),
    );
  }
}
