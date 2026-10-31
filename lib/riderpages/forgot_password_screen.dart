import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/services/auth_service.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/app_text_field.dart';
import 'package:rider_app/widgets/code_input.dart';
import 'package:rider_app/widgets/icon_tile.dart';
import 'package:rider_app/widgets/password_rules.dart';

/// "Forgot password?": a 6-digit code goes to the email registered on the
/// account (shown masked), then the rider sets a new password. Pops `true`
/// when the password was reset.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.email});

  /// What the rider typed in the login box.
  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _codeLength = 6;
  static const _resendSeconds = 60;

  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _masked;
  bool _sending = true;
  bool _saving = false;
  String? _error;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _codeFocus.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final masked = await authService.forgotPassword(widget.email);
      if (!mounted) return;
      setState(() => _masked = masked);
      _startCountdown();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _secondsLeft <= 1) {
        t.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  bool get _ready =>
      _code.text.length == _codeLength &&
      PasswordRules(_password.text).allMet &&
      _password.text == _confirm.text;

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await authService.resetPassword(widget.email, _code.text, _password.text, _confirm.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.message.toLowerCase().contains('code')) _code.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = PasswordRules(_password.text);
    final mismatch = _confirm.text.isNotEmpty && _confirm.text != _password.text;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ),
            AppSpacing.gapMd,
            const Center(child: IconTile(icon: Icons.lock_reset_rounded, size: 64)),
            AppSpacing.gapLg,
            Text('Reset your password', textAlign: TextAlign.center, style: AppTextStyles.h1.copyWith(fontSize: 24)),
            AppSpacing.gapSm,
            if (_sending)
              Text('Sending a code to your registered email…', textAlign: TextAlign.center, style: AppTextStyles.body)
            else if (_masked != null)
              Text.rich(
                TextSpan(
                  style: AppTextStyles.body,
                  children: [
                    const TextSpan(text: 'If this email is registered, we sent a 6-digit code to\n'),
                    TextSpan(text: _masked, style: AppTextStyles.bodyStrong.copyWith(fontSize: 14)),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            AppSpacing.gapXxl,
            if (_masked != null) ...[
              Text('Code', style: AppTextStyles.label),
              AppSpacing.gapSm,
              CodeInput(
                controller: _code,
                focusNode: _codeFocus,
                length: _codeLength,
                hasError: _error != null && _error!.toLowerCase().contains('code'),
              ),
              AppSpacing.gapSm,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Didn't get it? ", style: AppTextStyles.caption),
                  _secondsLeft > 0
                      ? Text('Resend in ${_secondsLeft}s', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700))
                      : InkWell(
                          onTap: _sending ? null : _send,
                          child: Text('Resend code', style: AppTextStyles.link),
                        ),
                ],
              ),
              AppSpacing.gapXl,
              AppTextField(
                label: 'New password',
                hint: 'Create a new password',
                controller: _password,
                isPassword: true,
                prefixIcon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
              ),
              AppSpacing.gapMd,
              PasswordRuleList(rules: rules),
              AppSpacing.gapLg,
              AppTextField(
                label: 'Confirm new password',
                hint: 'Type it again',
                controller: _confirm,
                isPassword: true,
                prefixIcon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _ready && !_saving ? _reset() : null,
              ),
              if (mismatch) ...[
                const SizedBox(height: 6),
                Text('The passwords do not match.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
              ],
            ],
            if (_error != null) ...[
              AppSpacing.gapLg,
              _ErrorBox(message: _error!),
            ],
            AppSpacing.gapXl,
            if (_masked != null)
              ListenableBuilder(
                listenable: _code,
                builder: (_, __) => AppButton(
                  label: 'Reset password',
                  isLoading: _saving,
                  onPressed: _ready && !_saving ? _reset : null,
                ),
              )
            else if (!_sending)
              AppButton(label: 'Try again', onPressed: _send),
            AppSpacing.gapLg,
            Text('All phones signed in to your account will be signed out.',
                textAlign: TextAlign.center, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
