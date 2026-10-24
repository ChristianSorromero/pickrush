import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/riderpages/application_status.dart';
import 'package:rider_app/riderpages/login.dart';
import 'package:rider_app/riderpages/register/step2_account.dart';
import 'package:rider_app/services/api_client.dart';
import 'register_shared.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.data});
  final RegisterData data;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _certified = false;
  bool _agreed = false;
  bool _submitting = false;
  double? _progress; // upload progress 0..1 while submitting
  String? _error;

  /// Picksell's limit per file (8 MB) and a safe total for one application.
  static const _maxFileBytes = 8 * 1024 * 1024;
  static const _maxTotalBytes = 45 * 1024 * 1024;

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  RegisterData get _d => widget.data;

  @override
  void initState() {
    super.initState();
    // TODO: open Terms of Service / Privacy Policy pages.
    _termsTap = TapGestureRecognizer()..onTap = () {};
    _privacyTap = TapGestureRecognizer()..onTap = () {};
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  // ── Navigation for EDIT links ──────────────────────────────────────────────
  // Stack: [Login, Step1, Step2, Step3, Step4, Review]
  // Resubmission: [Status, Step1, Step3, Step4, Review] (no email step)

  void _popBack(int count) {
    var n = 0;
    Navigator.of(context).popUntil((_) => n++ >= count);
  }

  // ── Formatting ─────────────────────────────────────────────────────────────

  String get _fullName => '${_d.firstName} ${_d.lastName}'.trim();

  String get _birthDate =>
      _d.birthDate == null ? '—' : formatRegisterDate(_d.birthDate!);

  String get _address {
    final parts = <String>[
      if (_d.street.isNotEmpty) _d.street,
      if (_d.barangay != null) _d.barangay!.name,
      if (_d.city != null) _d.city!.name,
      if (_d.province != null) _d.province!.name,
    ];
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  String get _mobile {
    final m = _d.mobile;
    if (m.length != 10) return '+63 $m';
    return '+63 ${m.substring(0, 3)} ${m.substring(3, 6)} ${m.substring(6)}';
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_certified || !_agreed) {
      setState(() => _error = 'Please accept both declarations before submitting.');
      return;
    }
    final tooBig = _checkFileSizes();
    if (tooBig != null) {
      setState(() => _error = tooBig);
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
      _progress = 0;
    });

    try {
      final form = FormData();

      // Text fields
      form.fields.addAll([
        MapEntry('first_name',               _d.firstName),
        MapEntry('last_name',                _d.lastName),
        MapEntry('birth_date',               _d.birthDate!.toIso8601String().substring(0, 10)),
        MapEntry('mobile',                   _d.mobile),
        MapEntry('hub_id',                   _d.hub!.id),
        MapEntry('province_code',            _d.province!.code),
        MapEntry('province_name',            _d.province!.name),
        MapEntry('city_code',                _d.city!.code),
        MapEntry('city_name',                _d.city!.name),
        MapEntry('barangay_code',            _d.barangay!.code),
        MapEntry('barangay_name',            _d.barangay!.name),
        MapEntry('street',                   _d.street),
        MapEntry('vehicle_type',             _d.vehicleType!.apiValue),
        MapEntry('plate_number',             _d.plateNumber),
        MapEntry('license_no',               _d.licenseNo),
        MapEntry('license_expiry',           _d.licenseExpiry!.toIso8601String().substring(0, 10)),
      ]);

      // A first application proves the email; a resubmission is signed in.
      if (!_d.isResubmission) {
        form.fields.addAll([
          MapEntry('email',                    _d.email),
          MapEntry('password',                 _d.password),
          MapEntry('email_verification_token', _d.emailVerificationToken),
        ]);
      }

      // Files
      form.files.add(MapEntry('license_front',
          await MultipartFile.fromFile(_d.licenseFrontPath!, filename: 'license_front.jpg')));
      form.files.add(MapEntry('license_back',
          await MultipartFile.fromFile(_d.licenseBackPath!, filename: 'license_back.jpg')));
      for (var i = 0; i < _d.registrationPaths.length; i++) {
        final path = _d.registrationPaths[i];
        final name = path.split(Platform.pathSeparator).last;
        form.files.add(MapEntry('orcr[$i]', await MultipartFile.fromFile(path, filename: name)));
      }

      // Photos travel from the phone through the tunnel to Picksell, which
      // can take well over the client's default 15 s on mobile data.
      await apiClient.post(
        _d.isResubmission ? '/api/rider/application' : '/api/rider/apply',
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) setState(() => _progress = sent / total);
        },
      );

      if (!mounted) return;
      _d.password = ''; // clear password from memory
      setState(() => _submitting = false);
      await _showSuccess();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = apiErrorMessage(e);
      // If the OTP token expired, send the rider back to the OTP screen
      final isTokenExpired = !_d.isResubmission &&
          e.response?.statusCode == 422 &&
          (e.response?.data?['errors']?['email_verification_token'] != null ||
              (msg.toLowerCase().contains('expired') &&
                  msg.toLowerCase().contains('verif')));
      if (isTokenExpired) {
        setState(() => _submitting = false);
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EmailOtpScreen(data: _d)),
        );
        return;
      }
      setState(() {
        _submitting = false;
        _error = msg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit your application. Please try again.';
      });
    }
  }

  /// Returns an error message when a file is over Picksell's limits.
  String? _checkFileSizes() {
    final paths = <String, String>{
      "License (front)": _d.licenseFrontPath!,
      "License (back)": _d.licenseBackPath!,
      for (final p in _d.registrationPaths)
        'OR/CR file ${p.split(Platform.pathSeparator).last}': p,
    };
    var total = 0;
    for (final entry in paths.entries) {
      final size = File(entry.value).lengthSync();
      if (size > _maxFileBytes) {
        return '${entry.key} is larger than 8 MB. Go back to Documents and '
            'use a smaller photo or file.';
      }
      total += size;
    }
    if (total > _maxTotalBytes) {
      return 'Your files are too large together. Go back to Documents and '
          'attach fewer or smaller OR/CR files.';
    }
    return null;
  }

  Future<void> _showSuccess() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: _SuccessDialog(
          resubmitted: _d.isResubmission,
          onDone: () {
            Navigator.of(dialogContext).pop();
            // A resubmitting rider is signed in: show their updated status.
            final Widget next = _d.isResubmission
                ? const ApplicationStatusScreen()
                : const LoginScreen();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => next),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final licenseOk =
        _d.licenseFrontPath != null && _d.licenseBackPath != null;
    final orcrOk = _d.registrationPaths.isNotEmpty;

    return RegisterStepScaffold(
      step: 5,
      title: 'Final Review',
      buttonLabel: 'Submit Registration',
      isLoading: _submitting,
      onContinue: _submitting ? null : _submit,
      onBack: () => Navigator.of(context).maybePop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewCard(
            icon: Icons.person_rounded,
            title: 'Personal Info',
            onEdit: () => _popBack(_d.isResubmission ? 3 : 4),
            children: [
              _InfoRow('Full Name', _fullName),
              _InfoRow('Birth Date', _birthDate),
              _InfoRow('Address', _address),
            ],
          ),
          AppSpacing.gapLg,
          _ReviewCard(
            icon: Icons.phone_rounded,
            title: 'Account & Contact',
            // Step 2, or Step 1 (mobile number) when resubmitting.
            onEdit: () => _popBack(3),
            children: [
              _InfoRow('Mobile', _mobile),
              _InfoRow('Email', _d.email),
            ],
          ),
          AppSpacing.gapLg,
          _ReviewCard(
            icon: Icons.two_wheeler_rounded,
            title: 'Work Setup',
            onEdit: () => _popBack(2),
            children: [
              _InfoRow('Vehicle Type', _d.vehicleType?.label ?? '—'),
              _InfoRow('Station Hub', _d.hub?.name ?? '—'),
            ],
          ),
          AppSpacing.gapLg,
          _ReviewCard(
            icon: Icons.folder_rounded,
            title: 'Documents Status',
            onEdit: () => _popBack(1),
            children: [
              _InfoRow('License No.',
                  _d.licenseNo.isEmpty ? '—' : _d.licenseNo),
              _InfoRow('Plate Number',
                  _d.plateNumber.isEmpty ? '—' : _d.plateNumber),
              _InfoRow(
                  'License Expiry',
                  _d.licenseExpiry == null
                      ? '—'
                      : formatRegisterDate(_d.licenseExpiry!)),
              _DocRow(
                icon: Icons.badge_outlined,
                title: "Driver's License",
                status: licenseOk ? 'BOTH SIDES ATTACHED' : 'INCOMPLETE',
                ok: licenseOk,
              ),
              _DocRow(
                icon: Icons.description_outlined,
                title: 'Vehicle OR/CR',
                status: orcrOk
                    ? '${_d.registrationPaths.length} FILE(S) ATTACHED'
                    : 'MISSING',
                ok: orcrOk,
              ),
            ],
          ),
          AppSpacing.gapXl,
          Text(
            'DECLARATIONS',
            style: AppTextStyles.overline.copyWith(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          AppSpacing.gapMd,
          _CheckCard(
            value: _certified,
            onChanged: (v) => setState(() {
              _certified = v;
              _error = null;
            }),
            child: Text(
              'I hereby certify that all information provided is true '
              'and correct to the best of my knowledge.',
              style: AppTextStyles.caption.copyWith(fontSize: 12, height: 1.4),
            ),
          ),
          AppSpacing.gapMd,
          _CheckCard(
            value: _agreed,
            onChanged: (v) => setState(() {
              _agreed = v;
              _error = null;
            }),
            child: Text.rich(
              TextSpan(
                style:
                    AppTextStyles.caption.copyWith(fontSize: 12, height: 1.4),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    recognizer: _termsTap,
                    style: AppTextStyles.link.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Data Privacy Policy',
                    recognizer: _privacyTap,
                    style: AppTextStyles.link.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: ' of Picksell.'),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            AppSpacing.gapMd,
            RegisterErrorBanner(message: _error!),
          ],
          if (_submitting && _progress != null) ...[
            AppSpacing.gapMd,
            Text(
              _progress! < 1
                  ? 'Uploading your documents… ${(_progress! * 100).round()}%'
                  : 'Upload done. Waiting for Picksell…',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: _progress! < 1 ? _progress : null,
              color: AppColors.primary,
              backgroundColor: AppColors.border,
            ),
          ],
          AppSpacing.gapLg,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_rounded,
                    size: 16, color: AppColors.primaryDark),
                AppSpacing.gapMd,
                Expanded(
                  child: Text(
                    'Once submitted, your station hub manager reviews your '
                    'documents and may call you for an interview. You can '
                    'log in to check your status.',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.primaryDark,
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

// ── Review card ──────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.icon,
    required this.title,
    required this.onEdit,
    required this.children,
  });

  final IconData icon;
  final String title;
  final VoidCallback onEdit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppTextStyles.overline.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              InkWell(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    'EDIT',
                    style: AppTextStyles.link.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label.toUpperCase(),
              style: AppTextStyles.overline.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyStrong.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.icon,
    required this.title,
    required this.status,
    required this.ok,
  });

  final IconData icon;
  final String title;
  final String status;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.primaryDark;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.bodyStrong.copyWith(fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: AppTextStyles.overline.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 20,
            color: color,
          ),
        ],
      ),
    );
  }
}

// ── Declarations ─────────────────────────────────────────────────────────────

class _CheckCard extends StatelessWidget {
  const _CheckCard({
    required this.value,
    required this.onChanged,
    required this.child,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 22,
            width: 22,
            child: Checkbox(
              value: value,
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              onChanged: (v) => onChanged(v ?? false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Success modal ────────────────────────────────────────────────────────────

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({required this.onDone, this.resubmitted = false});
  final VoidCallback onDone;
  final bool resubmitted;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withOpacity(0.12),
              ),
              child: Center(
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
            ),
            AppSpacing.gapLg,
            Text(
              resubmitted ? 'Application\nResubmitted!' : 'Registration\nSubmitted!',
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(fontSize: 24),
            ),
            AppSpacing.gapMd,
            Text(
              'Your station will review your application. You can log in '
              'anytime to check its status.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(fontSize: 13, height: 1.5),
            ),
            AppSpacing.gapXl,
            const _StatusTimeline(),
            AppSpacing.gapXl,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(resubmitted ? 'View Status' : 'Back to Login',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline();

  @override
  Widget build(BuildContext context) {
    Widget label(String t, Color c) => Text(
          t,
          style: AppTextStyles.overline.copyWith(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: c,
          ),
        );

    return Column(
      children: [
        Row(
          children: [
            Container(
              height: 14,
              width: 14,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.primary),
              child: const Icon(Icons.check_rounded,
                  size: 10, color: Colors.white),
            ),
            Expanded(child: Container(height: 2, color: AppColors.primary)),
            Container(
              height: 16,
              width: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Center(
                child: Container(
                  height: 6,
                  width: 6,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            label('SUBMITTED', AppColors.primary),
            label('PENDING REVIEW', AppColors.primary),
          ],
        ),
      ],
    );
  }
}