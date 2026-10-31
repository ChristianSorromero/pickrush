import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/services/email_otp_service.dart';
import 'package:rider_app/widgets/code_input.dart';
import 'package:rider_app/widgets/password_rules.dart';
import 'register_shared.dart';
import 'step3_work_setup.dart';

// ── Step 2 — Account Security ─────────────────────────────────────────────────

class AccountCreationScreen extends StatefulWidget {
  const AccountCreationScreen({super.key, required this.data});
  final RegisterData data;

  @override
  State<AccountCreationScreen> createState() => _AccountCreationScreenState();
}

class _AccountCreationScreenState extends State<AccountCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final email = _email.text.trim();
      await otpService.sendEmailOtp(email);
      if (!mounted) return;

      widget.data
        ..email = email
        ..password = _password.text;

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EmailOtpScreen(data: widget.data)),
      );
    } on OtpException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send the code. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = PasswordRules(_password.text);

    return RegisterStepScaffold(
      step: 2,
      title: 'Account Security',
      buttonLabel: 'Verify & Continue',
      isLoading: _loading,
      onContinue: _onContinue,
      onBack: () => Navigator.of(context).maybePop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RegisterSectionHeader('Login Credentials'),
            AppSpacing.gapLg,
            RegisterLabeledField(
              label: 'Email Address',
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                style: AppTextStyles.bodyStrong,
                decoration: registerInputDecoration('juan.delacruz@email.com'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Required';
                  final ok =
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                  return ok ? null : 'Enter a valid email address';
                },
              ),
            ),
            AppSpacing.gapLg,
            RegisterLabeledField(
              label: 'Password',
              child: _PasswordField(
                controller: _password,
                hint: '••••••••',
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    PasswordRules(v ?? '').allMet ? null : 'Password is too weak',
              ),
            ),
            AppSpacing.gapMd,
            PasswordRuleList(rules: rules),
            AppSpacing.gapLg,
            RegisterLabeledField(
              label: 'Confirm Password',
              child: _PasswordField(
                controller: _confirm,
                hint: 'Re-type password',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  return v == _password.text ? null : 'Passwords do not match';
                },
              ),
            ),
            AppSpacing.gapXl,
          ],
        ),
      ),
    );
  }
}

// ── Step 2b — Email OTP ───────────────────────────────────────────────────────

class EmailOtpScreen extends StatefulWidget {
  const EmailOtpScreen({super.key, required this.data});
  final RegisterData data;

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  static const _length = 6;
  static const _cooldown = 300;

  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _secondsLeft = _cooldown;
  bool _verifying = false;
  bool _error = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _code.addListener(_onCodeChanged);
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _secondsLeft = _cooldown;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _onCodeChanged() {
    setState(() {
      if (_error && _code.text.isNotEmpty) _error = false;
    });
    if (_code.text.length == _length && !_verifying) _verify();
  }

  Future<void> _verify() async {
    if (_code.text.length != _length || _verifying) return;
    FocusScope.of(context).unfocus();
    setState(() => _verifying = true);

    OtpResult result;
    try {
      result = await otpService.verifyEmailOtp(widget.data.email, _code.text);
    } catch (_) {
      result = const OtpResult.failure('Something went wrong. Please try again.');
    }
    if (!mounted) return;

    if (result.ok) {
      widget.data.emailVerificationToken = result.token ?? '';
      setState(() => _verifying = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => WorkSetupScreen(data: widget.data)),
      );
    } else {
      setState(() {
        _verifying = false;
        _error = true;
        _errorMessage = result.message ?? 'Incorrect code. Please try again.';
      });
      _code.clear();
      _focus.requestFocus();
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    try {
      await otpService.sendEmailOtp(widget.data.email);
      if (!mounted) return;
      _code.clear();
      setState(() => _error = false);
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent.')),
      );
    } on OtpException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not resend the code.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RegisterStepScaffold(
      step: 2,
      title: 'Verify Email',
      buttonLabel: 'Verify & Continue',
      isLoading: _verifying,
      onContinue: _code.text.length == _length ? _verify : null,
      onBack: () => Navigator.of(context).maybePop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RegisterSectionHeader('Verification'),
          AppSpacing.gapLg,
          Text.rich(
            TextSpan(
              style: AppTextStyles.body.copyWith(fontSize: 13),
              children: [
                const TextSpan(text: "We've sent a 6-digit verification code to "),
                TextSpan(
                  text: widget.data.email,
                  style:
                      AppTextStyles.bodyStrong.copyWith(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          AppSpacing.gapXl,
          CodeInput(
            controller: _code,
            focusNode: _focus,
            length: _length,
            hasError: _error,
          ),
          if (_error) ...[
            AppSpacing.gapMd,
            Center(
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          AppSpacing.gapXl,
          Center(
            child: Column(
              children: [
                Text("Didn't receive the code?",
                    style: AppTextStyles.body.copyWith(fontSize: 13)),
                const SizedBox(height: 4),
                if (_secondsLeft > 0)
                  Text(
                    'Resend code in ${_secondsLeft}s',
                    style: AppTextStyles.link.copyWith(fontWeight: FontWeight.w700),
                  )
                else
                  InkWell(
                    onTap: _resend,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        'Resend code',
                        style: AppTextStyles.link.copyWith(
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AppSpacing.gapXl,
        ],
      ),
    );
  }
}

// ── Password helpers ──────────────────────────────────────────────────────────

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.hint,
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      onChanged: widget.onChanged,
      validator: widget.validator,
      autocorrect: false,
      enableSuggestions: false,
      style: AppTextStyles.bodyStrong,
      decoration: registerInputDecoration(
        widget.hint,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
