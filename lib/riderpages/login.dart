import 'package:flutter/material.dart';

import 'package:rider_app/riderpages/application_status.dart';
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
      final account = await authService.login(email, _password.text,
          remember: _rememberMe);
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

  void _onForgotPassword() {
    // TODO: forgot password flow
  }

  void _onRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: BrandLogo()),
              AppSpacing.gapXl,
              Center(
                child: Text(
                  'Welcome Back, Rider',
                  style: AppTextStyles.h1.copyWith(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
              ),
              AppSpacing.gapSm,
              Center(
                child: Text(
                  'Sign in to manage your pickups and deliveries.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ),
              AppSpacing.gapXxl,
              AppTextField(
                label: 'Email Address',
                hint: 'Enter your email address',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline_rounded,
              ),
              AppSpacing.gapLg,
              AppTextField(
                label: 'Password',
                hint: 'Enter your password',
                controller: _password,
                prefixIcon: Icons.lock_outline_rounded,
                isPassword: true,
              ),
              AppSpacing.gapMd,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppCheckboxTile(
                    label: 'Remember me',
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v),
                  ),
                  InkWell(
                    onTap: _onForgotPassword,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('Forgot password?',
                          style: AppTextStyles.bodyStrong),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                AppSpacing.gapMd,
                Text(
                  _error!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              AppSpacing.gapXl,
              AppButton(
                label: 'Sign In',
                isLoading: _loading,
                onPressed: _loading ? null : _onSignIn,
              ),
              AppSpacing.gapXxl,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Want to be a rider? ', style: AppTextStyles.body),
                  InkWell(
                    onTap: _onRegister,
                    child: Text(
                      'Register here.',
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}