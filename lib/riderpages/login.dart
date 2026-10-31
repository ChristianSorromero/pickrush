import 'package:flutter/material.dart';

import 'package:rider_app/riderpages/application_status.dart';
import 'package:rider_app/riderpages/forgot_password_screen.dart';
import 'package:rider_app/riderpages/main_shell.dart';
import 'package:rider_app/riderpages/register/register.dart';
import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/services/auth_service.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/app_checkbox_tile.dart';
import 'package:rider_app/widgets/app_text_field.dart';
import 'package:rider_app/widgets/brand_logo.dart';

/// Sign in with email and password. Also the way into "Forgot password?"
/// (a code to the registered email) and applying as a new rider.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = true;
  bool _loading = false;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Active riders go to the dashboard; applicants see their status.
  Future<void> _onSignIn() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await authService.login(email, _password.text, remember: _rememberMe);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => account.status == RiderStatus.active
            ? const MainShell()
            : ApplicationStatusScreen(account: account),
      ));
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The code goes to the email typed above (only if it is registered).
  Future<void> _onForgotPassword() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Type your registered email above, then tap "Forgot password?".');
      return;
    }
    setState(() => _error = null);
    final reset = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ForgotPasswordScreen(email: email)),
    );
    if (reset == true && mounted) {
      _password.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset. Log in with your new password.')),
      );
    }
  }

  void _onRegister() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: ConstrainedBox(
              // Fill the screen so the footer sits at the bottom; scroll when the keyboard is up.
              constraints: BoxConstraints(minHeight: viewport.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 2),
                    const _Hero(),
                    const SizedBox(height: 36),
                    _form(),
                    const Spacer(flex: 3),
                    _Footer(onRegister: _onRegister),
                    AppSpacing.gapLg,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Email Address',
            hint: 'you@example.com',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline_rounded,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          AppSpacing.gapLg,
          AppTextField(
            label: 'Password',
            hint: 'Enter your password',
            controller: _password,
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _loading ? null : _onSignIn(),
          ),
          AppSpacing.gapMd,
          Row(
            children: [
              AppCheckboxTile(
                label: 'Remember me',
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v),
              ),
              const Spacer(),
              TextButton(
                onPressed: _onForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 36),
                  textStyle: AppTextStyles.link,
                ),
                child: const Text('Forgot password?'),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: _ErrorBox(message: _error!),
                  ),
          ),
          AppSpacing.gapXl,
          AppButton(
            label: 'Sign In',
            isLoading: _loading,
            onPressed: _loading ? null : _onSignIn,
          ),
        ],
      ),
    );
  }
}

/// Logo, greeting and what the app is for.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BrandLogo(height: 60),
        AppSpacing.gapMd,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.pillAll),
          child: Text(
            'RIDER APP',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('Welcome back, Rider', textAlign: TextAlign.center, style: AppTextStyles.h1.copyWith(fontSize: 26)),
        AppSpacing.gapSm,
        Text(
          'Sign in to manage your pickups and deliveries.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ],
    );
  }
}

/// New riders: apply here. The station reviews the application.
class _Footer extends StatelessWidget {
  const _Footer({required this.onRegister});
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('New to Pickrush?', style: AppTextStyles.caption),
            ),
            const Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        AppSpacing.gapMd,
        AppButton(
          label: 'Apply as a Rider',
          variant: AppButtonVariant.outline,
          onPressed: onRegister,
        ),
        AppSpacing.gapMd,
        Text(
          'Pickrush Logistics · a PickSell company',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.mdAll),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.primaryDark),
          AppSpacing.gapSm,
          Expanded(
            child: Text(message, style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primaryDark)),
          ),
        ],
      ),
    );
  }
}
