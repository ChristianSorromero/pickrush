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
import 'package:rider_app/app_assets.dart';
import 'package:rider_app/widgets/app_feedback.dart';

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
      final account =
          await authService.login(email, _password.text, remember: _rememberMe);
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
      setState(() => _error =
          'Type your registered email above, then tap "Forgot password?".');
      return;
    }
    setState(() => _error = null);
    final reset = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ForgotPasswordScreen(email: email)),
    );
    if (reset == true && mounted) {
      _password.clear();
      AppToast.success(
          context, 'Password reset. Log in with your new password.');
    }
  }

  void _onRegister() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          child: ConstrainedBox(
            // Fill the screen so the footer sits at the bottom; scroll when the keyboard is up.
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hero(topInset: MediaQuery.paddingOf(context).top),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH),
                    child: Transform.translate(
                      offset: const Offset(0, -36),
                      child: _FormCard(child: _form()),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH),
                    child: _Footer(onRegister: _onRegister),
                  ),
                  SizedBox(
                      height:
                          AppSpacing.lg + MediaQuery.paddingOf(context).bottom),
                ],
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
          Text('Welcome back, Rider', style: AppTextStyles.h1),
          AppSpacing.gapXs,
          Text('Sign in to manage your pickups and deliveries.',
              style: AppTextStyles.body),
          AppSpacing.gapXxl,
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

/// Warm branded band: logo badge, app name and the "Rider app" tag.
/// The form card overlaps its rounded bottom edge.
class _Hero extends StatelessWidget {
  const _Hero({required this.topInset});
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, topInset + 40, 24, 72),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE3D6), AppColors.primarySoft, Color(0xFFFFF6F1)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Soft decorative rings, echoing the logo's speed lines.
          const Positioned(right: -60, top: -50, child: _Ring(size: 170)),
          const Positioned(left: -70, bottom: -40, child: _Ring(size: 130)),
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFFE96C36).withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Image.asset(AppAssets.logoMark),
                ),
                const SizedBox(height: 18),
                Text(
                  'PSL Logistics',
                  style: AppTextStyles.h1
                      .copyWith(fontSize: 28, letterSpacing: -0.3),
                ),
                AppSpacing.gapSm,
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.75),
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.two_wheeler_rounded,
                          size: 15, color: AppColors.primaryDark),
                      const SizedBox(width: 6),
                      Text(
                        'RIDER APP',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: const Color(0xFFE96C36).withValues(alpha: 0.12), width: 18),
      ),
    );
  }
}

/// White card that holds the sign-in form.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 30, offset: Offset(0, 12)),
        ],
      ),
      child: child,
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
              child: Text('New rider?', style: AppTextStyles.caption),
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
          'PSL Logistics · Delivery partner of PickSell',
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
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.errorSoft, borderRadius: AppRadius.mdAll),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.errorStrong),
          AppSpacing.gapSm,
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodyStrong
                    .copyWith(color: AppColors.errorStrong)),
          ),
        ],
      ),
    );
  }
}
