import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/riderpages/login.dart';
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/auth_service.dart';
import 'package:rider_app/services/launcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/app_text_field.dart';
import 'package:rider_app/widgets/section_card.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

/// Account tab: who the rider is to their station, their vehicle, documents
/// and payout details (read-only: the station keeps these), going online,
/// changing the password, and logging out.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  RiderAccount? _account;
  String? _error;
  bool _switching = false;
  int _seenChanges = -1;

  @override
  void initState() {
    super.initState();
    assignmentWatcher.addListener(_onWatcher);
    _load();
  }

  @override
  void dispose() {
    assignmentWatcher.removeListener(_onWatcher);
    super.dispose();
  }

  void _onWatcher() {
    if (assignmentWatcher.changes != _seenChanges) _load();
  }

  Future<void> _load() async {
    _seenChanges = assignmentWatcher.changes;
    try {
      final account = await authService.me();
      if (mounted) {
        setState(() {
          _account = account;
          _error = null;
        });
      }
    } on AuthException catch (e) {
      if (e.signedOut) return _toLogin();
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setOnline(bool online) async {
    setState(() => _switching = true);
    try {
      await riderTasks.setOnline(online);
      assignmentWatcher.touch(); // Home reloads too
      _toast(online ? 'You are online. New tasks can be assigned to you.' : 'You are offline. No new tasks will be assigned.');
    } on TaskException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will stop getting new assignments on this phone until you log in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    assignmentWatcher.reset();
    await authService.logout();
    _toLogin();
  }

  void _toLogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _account;
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
          children: [
            Text('Account', style: AppTextStyles.h1),
            AppSpacing.gapXl,
            if (a == null)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: _error == null
                      ? const CircularProgressIndicator(color: AppColors.primary)
                      : Column(
                          children: [
                            Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.body),
                            AppSpacing.gapLg,
                            AppButton(label: 'Try again', onPressed: _load, expand: false),
                          ],
                        ),
                ),
              )
            else ...[
              _ProfileHeader(account: a),
              AppSpacing.gapLg,
              _OnlineCard(online: a.isOnline, busy: _switching, onChanged: _setOnline),
              ..._expiryBanner(a),
              AppSpacing.gapXl,
              _work(a),
              AppSpacing.gapXl,
              _vehicle(a),
              AppSpacing.gapXl,
              _documents(a),
              AppSpacing.gapXl,
              _payout(a),
              AppSpacing.gapXl,
              _contact(a),
              AppSpacing.gapXl,
              SectionCard(
                title: 'Security',
                children: [
                  InfoRow(
                    icon: Icons.lock_outline_rounded,
                    label: 'Password',
                    value: 'Change password',
                    onTap: () => showChangePassword(context),
                  ),
                ],
              ),
              AppSpacing.gapXxl,
              AppButton(label: 'Log Out', variant: AppButtonVariant.outline, onPressed: _logout),
              AppSpacing.gapMd,
              Center(child: Text('Pickrush Rider · v0.1.0', style: AppTextStyles.caption)),
              AppSpacing.gapLg,
            ],
          ],
        ),
      ),
    );
  }

  /// A warning when the license expires within 30 days (or already has).
  List<Widget> _expiryBanner(RiderAccount a) {
    final days = _daysLeft(a.licenseExpiry);
    if (days == null || days > 30) return const [];
    final expired = days < 0;
    return [
      AppSpacing.gapLg,
      Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: expired ? AppColors.primarySoft : AppColors.warningSoft,
          borderRadius: AppRadius.lgAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: expired ? AppColors.primaryDark : AppColors.warning),
            AppSpacing.gapMd,
            Expanded(
              child: Text(
                expired
                    ? 'Your driver\'s license has expired. Renew it and send the new one to your station to keep riding.'
                    : 'Your driver\'s license expires in $days ${days == 1 ? 'day' : 'days'}. Renew it and send the new one to your station.',
                style: AppTextStyles.bodyStrong.copyWith(color: expired ? AppColors.primaryDark : AppColors.warning),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _work(RiderAccount a) => SectionCard(
        title: 'Work',
        children: [
          InfoRow(
            icon: Icons.apartment_rounded,
            label: 'Station',
            value: [a.station?.name, a.station?.city].whereType<String>().join(' · '),
          ),
          InfoRow(icon: Icons.map_outlined, label: 'Delivery zone', value: a.zone ?? 'Not assigned yet'),
          if (a.codLimit != null)
            InfoRow(icon: Icons.payments_outlined, label: 'COD limit', value: FormatUtils.peso(a.codLimit!)),
          if (a.maxParcels != null)
            InfoRow(icon: Icons.inventory_2_outlined, label: 'Parcels per day', value: 'Up to ${a.maxParcels}'),
          if (a.approvedAt != null)
            InfoRow(icon: Icons.verified_outlined, label: 'Rider since', value: _longDate(a.approvedAt!)),
        ],
      );

  Widget _vehicle(RiderAccount a) {
    final days = _daysLeft(a.licenseExpiry);
    return SectionCard(
      title: 'Vehicle & license',
      children: [
        InfoRow(
          icon: a.vehicleType == 'tricycle' ? Icons.electric_rickshaw_outlined : Icons.two_wheeler_rounded,
          label: 'Vehicle',
          value: _title(a.vehicleType ?? '—'),
        ),
        InfoRow(icon: Icons.pin_outlined, label: 'Plate number', value: a.plateNumber ?? '—'),
        InfoRow(icon: Icons.badge_outlined, label: 'License number', value: a.licenseNo ?? '—'),
        if (a.licenseExpiry != null)
          InfoRow(
            icon: Icons.event_outlined,
            label: 'License expiry',
            value: _longDate(a.licenseExpiry!),
            trailing: _expiryChip(days),
          ),
      ],
    );
  }

  Widget _documents(RiderAccount a) {
    final docs = a.documents;
    return SectionCard(
      title: 'Documents',
      children: docs.isEmpty
          ? [
              const InfoRow(icon: Icons.description_outlined, label: 'No documents on file', value: 'Your station keeps your documents'),
            ]
          : [
              for (final d in docs)
                InfoRow(
                  icon: Icons.description_outlined,
                  label: d.title,
                  value: d.expiry == null ? 'On file' : 'Valid until ${_longDate(d.expiry!)}',
                  trailing: d.expiry == null ? const TagChip.success(label: 'On file') : _expiryChip(d.daysLeft()),
                ),
            ],
    );
  }

  Widget _payout(RiderAccount a) {
    final p = a.payout;
    return SectionCard(
      title: 'Payout',
      children: [
        p == null
            ? const InfoRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Payout method',
                value: 'Not set — ask your station to add it',
              )
            : InfoRow(
                icon: Icons.account_balance_wallet_outlined,
                label: switch (p.method) { 'gcash' => 'GCash', 'maya' => 'Maya', _ => 'Bank account' },
                value: p.account ?? '—',
              ),
      ],
    );
  }

  Widget _contact(RiderAccount a) {
    final station = a.stationContact;
    final emergency = a.emergencyContact;
    return SectionCard(
      title: 'Contact details',
      children: [
        InfoRow(icon: Icons.phone_iphone_rounded, label: 'Mobile', value: a.mobile == null ? '—' : '+63 ${a.mobile}'),
        InfoRow(icon: Icons.alternate_email_rounded, label: 'Email', value: a.email),
        if (a.fullAddress.isNotEmpty) InfoRow(icon: Icons.home_outlined, label: 'Address', value: a.fullAddress),
        if (emergency != null)
          InfoRow(
            icon: Icons.contact_emergency_outlined,
            label: 'Emergency contact',
            value: [emergency.name, emergency.mobile].whereType<String>().join(' · '),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'To change any of these, contact your station${station != null ? ' (${station.name})' : ''}.',
                  style: AppTextStyles.caption,
                ),
              ),
              if (station?.mobile != null)
                TextButton.icon(
                  onPressed: () => Launcher.call(station!.mobile!),
                  icon: const Icon(Icons.call_outlined, size: 16),
                  label: const Text('Call'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.account});
  final RiderAccount account;

  @override
  Widget build(BuildContext context) {
    final a = account;
    final initials = a.fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    return SurfaceCard(
      child: Row(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(initials.isEmpty ? '?' : initials,
                style: AppTextStyles.h2.copyWith(fontSize: 22, color: AppColors.primaryDark)),
          ),
          AppSpacing.gapLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.fullName, style: AppTextStyles.h2.copyWith(fontSize: 18)),
                Text(a.email, style: AppTextStyles.caption),
                AppSpacing.gapSm,
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    TagChip.success(label: a.status == RiderStatus.active ? 'Active rider' : a.status.name),
                    if (a.onProbation) const TagChip.warning(label: 'On probation'),
                    TagChip.muted(label: 'Rider #${a.id}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineCard extends StatelessWidget {
  const _OnlineCard({required this.online, required this.busy, required this.onChanged});
  final bool online;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            height: 12,
            width: 12,
            decoration: BoxDecoration(
              color: online ? AppColors.success : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(online ? 'Online' : 'Offline', style: AppTextStyles.bodyStrong),
                Text(online ? 'Your station can assign you tasks' : 'No new tasks will be assigned',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          busy
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
              : Switch(
                  value: online,
                  onChanged: onChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.success,
                ),
        ],
      ),
    );
  }
}

/// "Change password": current, new, and confirm. Other phones get signed out.
Future<void> showChangePassword(BuildContext context) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (_) => const _PasswordSheet(),
  );
  if (changed == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed. Other phones were signed out.')));
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Same rule as when applying: 8+ characters with upper, lower, a number and a symbol.
  static String? _strong(String? v) {
    final s = v ?? '';
    if (s.length < 8) return 'At least 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(s) || !RegExp(r'[a-z]').hasMatch(s)) return 'Use upper- and lower-case letters.';
    if (!RegExp(r'\d').hasMatch(s)) return 'Add a number.';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(s)) return 'Add a symbol (e.g. ! @ #).';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await authService.changePassword(_current.text, _next.text, _confirm.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.lg),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Change password', style: AppTextStyles.h2.copyWith(fontSize: 18)),
                const SizedBox(height: 2),
                Text('Other phones signed in to your account will be signed out.', style: AppTextStyles.caption),
                AppSpacing.gapLg,
                AppTextField(
                  label: 'Current password',
                  hint: 'Your current password',
                  controller: _current,
                  isPassword: true,
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: (v) => (v ?? '').isEmpty ? 'Enter your current password.' : null,
                ),
                AppSpacing.gapLg,
                AppTextField(
                  label: 'New password',
                  hint: '8+ characters, Aa, 1, !',
                  controller: _next,
                  isPassword: true,
                  prefixIcon: Icons.key_outlined,
                  validator: _strong,
                ),
                AppSpacing.gapLg,
                AppTextField(
                  label: 'Confirm new password',
                  hint: 'Type it again',
                  controller: _confirm,
                  isPassword: true,
                  prefixIcon: Icons.key_outlined,
                  validator: (v) => v != _next.text ? 'The passwords do not match.' : null,
                ),
                if (_error != null) ...[
                  AppSpacing.gapMd,
                  Text(_error!, style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primaryDark)),
                ],
                AppSpacing.gapXl,
                AppButton(label: 'Save new password', isLoading: _saving, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int? _daysLeft(DateTime? expiry) {
  if (expiry == null) return null;
  final now = DateTime.now();
  return DateTime(expiry.year, expiry.month, expiry.day).difference(DateTime(now.year, now.month, now.day)).inDays;
}

Widget _expiryChip(int? days) {
  if (days == null) return const SizedBox.shrink();
  if (days < 0) return const TagChip(label: 'Expired');
  if (days <= 30) return TagChip.warning(label: days == 0 ? 'Expires today' : 'Expires in $days d');
  return const TagChip.success(label: 'Valid');
}

String _longDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _title(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
