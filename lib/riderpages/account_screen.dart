import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/riderpages/document_update_screen.dart';
import 'package:rider_app/riderpages/login.dart';
import 'package:rider_app/riderpages/register/register_data.dart' show VehicleType;
import 'package:rider_app/services/assignment_watcher.dart';
import 'package:rider_app/services/auth_service.dart';
import 'package:rider_app/services/launcher.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/tab_header.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/app_text_field.dart';
import 'package:rider_app/widgets/section_card.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';
import 'package:rider_app/widgets/app_feedback.dart';

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

  void _toast(String message, {ToastType type = ToastType.success}) {
    if (mounted) AppToast.show(context, message, type: type);
  }

  Future<void> _setOnline(bool online) async {
    setState(() => _switching = true);
    try {
      await riderTasks.setOnline(online);
      assignmentWatcher.touch(); // Home reloads too
      _toast(online ? 'You are online. New tasks can be assigned to you.' : 'You are offline. No new tasks will be assigned.');
    } on TaskException catch (e) {
      _toast(e.message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'You will stop getting new assignments on this phone until you log in again.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!ok) return;
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
            TabHeader(title: 'Account', onNotificationsClosed: _load),
            AppSpacing.gapXl,
            if (a == null)
              _error == null
                  ? const StateView.loading(skeleton: CardListSkeleton(count: 4))
                  : StateView.error(message: _error!, onRetry: _load)
            else ...[
              _ProfileHeader(account: a),
              AppSpacing.gapLg,
              _OnlineCard(online: a.isOnline, busy: _switching, onChanged: _setOnline),
              ..._expiryBanner(a),
              AppSpacing.gapXl,
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
                child: Text('YOUR DETAILS', style: AppTextStyles.overline),
              ),
              _documents(a),
              AppSpacing.gapMd,
              _work(a),
              AppSpacing.gapMd,
              _vehicle(a),
              AppSpacing.gapMd,
              _payout(a),
              AppSpacing.gapMd,
              _contact(a),
              AppSpacing.gapMd,
              _security(),
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

  /// A warning for each license or OR/CR that expires within 30 days or
  /// already has: an expired one means no new tasks until a renewal is approved.
  List<Widget> _expiryBanner(RiderAccount a) {
    final banners = <Widget>[];
    for (final (type, name, expiry) in [
      ('drivers_license', "driver's license", a.licenseExpiry),
      ('or_cr', 'OR/CR', a.orcrExpiry),
    ]) {
      final days = _daysLeft(expiry);
      if (days == null || days > 30) continue;
      final expired = days < 0;
      final waiting = a.updateFor(type)?.isPending ?? false;
      final text = switch ((expired, waiting)) {
        (true, true) => 'Your $name has expired. You get no new tasks until your station approves the new one you sent.',
        (true, false) => 'Your $name has expired. You get no new tasks until you send a renewed one and your station approves it.',
        (false, true) => 'Your $name expires ${_inDays(days)}. Your station is reviewing the new one you sent.',
        (false, false) => 'Your $name expires ${_inDays(days)}. Renew it and send the new one so you can keep riding.',
      };
      banners.addAll([
        AppSpacing.gapLg,
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: expired ? AppColors.errorSoft : AppColors.warningSoft,
            borderRadius: AppRadius.lgAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(expired ? Icons.gpp_bad_outlined : Icons.event_busy_outlined,
                      color: expired ? AppColors.errorStrong : AppColors.warning),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Text(text,
                        style: AppTextStyles.bodyStrong.copyWith(color: expired ? AppColors.errorStrong : AppColors.warning)),
                  ),
                ],
              ),
              if (!waiting)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _renew(a, type),
                    child: Text(type == 'or_cr' ? 'Renew OR/CR' : 'Renew license'),
                  ),
                ),
            ],
          ),
        ),
      ]);
    }
    return banners;
  }

  static String _inDays(int days) => days == 0 ? 'today' : 'in $days ${days == 1 ? 'day' : 'days'}';

  Future<void> _renew(RiderAccount a, String type) async {
    final updated = await Navigator.of(context).push<RiderAccount>(
      MaterialPageRoute(builder: (_) => DocumentUpdateScreen(type: type, licenseNo: a.licenseNo)),
    );
    if (updated != null && mounted) setState(() => _account = updated);
  }

  Widget _work(RiderAccount a) => CollapsibleSection(
        icon: Icons.work_outline_rounded,
        title: 'Work assignment',
        summary: [a.company?.name, a.station?.name].whereType<String>().join(' · '),
        children: [
          if (a.company != null)
            InfoRow(icon: Icons.business_rounded, label: 'Logistics company (hired by)', value: a.company!.name),
          InfoRow(
            icon: Icons.warehouse_outlined,
            label: 'Station',
            value: [a.station?.name, a.station?.city].whereType<String>().join(' · '),
          ),
          InfoRow(icon: Icons.share_location_rounded, label: 'Delivery zone', value: a.zone ?? 'Not assigned yet'),
          if (a.codLimit != null)
            InfoRow(icon: Icons.price_check_rounded, label: 'COD limit (cash you can carry)', value: FormatUtils.peso(a.codLimit!)),
          if (a.maxParcels != null)
            InfoRow(icon: Icons.all_inbox_outlined, label: 'Parcels per day', value: 'Up to ${a.maxParcels}'),
          if (a.approvedAt != null)
            InfoRow(icon: Icons.workspace_premium_outlined, label: 'Rider since', value: _longDate(a.approvedAt!)),
        ],
      );

  static IconData _vehicleIcon(String? type) => switch (type) {
        'tricycle' => Icons.electric_rickshaw_outlined,
        'four_wheel' => Icons.airport_shuttle_outlined,
        _ => Icons.two_wheeler_rounded,
      };

  Widget _vehicle(RiderAccount a) {
    final type = VehicleType.fromApi(a.vehicleType)?.label ?? _title(a.vehicleType ?? '—');
    return CollapsibleSection(
      icon: _vehicleIcon(a.vehicleType),
      title: 'Vehicle',
      summary: [type, a.plateNumber].whereType<String>().join(' · '),
      children: [
        InfoRow(icon: _vehicleIcon(a.vehicleType), label: 'Type', value: type),
        InfoRow(icon: Icons.pin_outlined, label: 'Plate number', value: a.plateNumber ?? '—'),
      ],
    );
  }

  /// The license and the OR/CR in one place: number, expiry, renewal status
  /// and a Renew button each. Opens by itself when one needs the rider.
  Widget _documents(RiderAccount a) {
    final docs = a.documents;
    final types = {for (final d in docs) d.type}.toList();
    final soonest = docs.map((d) => d.daysLeft()).whereType<int>().fold<int?>(null, (m, v) => m == null || v < m ? v : m);
    final pending = types.any((t) => a.updateFor(t)?.isPending ?? false);
    final rejected = types.any((t) => a.updateFor(t)?.isRejected ?? false);
    final tone = soonest != null && soonest < 0
        ? TaskTone.failed
        : (soonest != null && soonest <= 30) || rejected
            ? TaskTone.attention
            : null;
    final summary = docs.isEmpty
        ? 'Your station keeps your documents'
        : soonest != null && soonest < 0
            ? 'A document has expired — renew it'
            : soonest != null && soonest <= 30
                ? 'A document expires ${_inDays(soonest)}'
                : rejected
                    ? 'A renewal was not accepted'
                    : pending
                        ? 'Renewal waiting for your station'
                        : 'All valid';

    return CollapsibleSection(
      icon: Icons.folder_shared_outlined,
      title: 'License & documents',
      summary: summary,
      attention: tone,
      initiallyExpanded: tone != null,
      children: docs.isEmpty
          ? const [InfoRow(icon: Icons.description_outlined, label: 'No documents on file', value: 'Your station keeps your documents')]
          : [
              for (final type in types)
                Builder(builder: (context) {
                  final d = docs.firstWhere((d) => d.type == type);
                  final license = type == 'drivers_license';
                  final days = d.daysLeft();
                  final expired = days != null && days < 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InfoRow(
                        icon: license ? Icons.badge_outlined : Icons.receipt_long_outlined,
                        iconColor: expired ? AppColors.errorStrong : null,
                        label: license ? "Driver's license${a.licenseNo == null ? '' : ' · ${a.licenseNo}'}" : 'Registration (OR/CR)',
                        value: d.expiry == null ? 'On file' : 'Valid until ${_longDate(d.expiry!)}',
                        trailing: d.expiry == null ? const TagChip.success(label: 'On file') : _expiryChip(days),
                      ),
                      ..._updateStatus(a.updateFor(type)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _renew(a, type),
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: Text(a.updateFor(type)?.isPending ?? false ? 'Send again' : 'Renew'),
                        ),
                      ),
                    ],
                  );
                }),
            ],
    );
  }

  /// "Waiting for your station" or "Not accepted: reason" for a renewal.
  List<Widget> _updateStatus(DocumentUpdateInfo? u) {
    if (u == null || !(u.isPending || u.isRejected)) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(left: 40, bottom: AppSpacing.xs),
        child: Text(
          u.isPending
              ? 'New one sent${u.sentAt == null ? '' : ' ${_longDate(u.sentAt!)}'}: waiting for your station to approve it.'
              : 'Your new one was not accepted: ${u.reason ?? 'ask your station why'}',
          style: AppTextStyles.caption.copyWith(color: u.isPending ? AppColors.warning : AppColors.errorStrong),
        ),
      ),
    ];
  }

  Widget _payout(RiderAccount a) {
    final p = a.payout;
    final method = p == null ? null : switch (p.method) { 'gcash' => 'GCash', 'maya' => 'Maya', _ => 'Bank account' };
    final masked = p?.account == null || p!.account!.length < 4 ? p?.account : '•••• ${p.account!.substring(p.account!.length - 4)}';
    return CollapsibleSection(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Payout',
      summary: p == null ? 'Not set — ask your station' : '$method · $masked',
      attention: p == null ? TaskTone.attention : null,
      children: [
        p == null
            ? const InfoRow(icon: Icons.help_outline_rounded, label: 'Payout method', value: 'Not set — ask your station to add it')
            : InfoRow(
                icon: p.method == 'gcash' || p.method == 'maya' ? Icons.smartphone_rounded : Icons.account_balance_outlined,
                label: method!,
                value: p.account ?? '—',
              ),
      ],
    );
  }

  Widget _contact(RiderAccount a) {
    final station = a.stationContact;
    final emergency = a.emergencyContact;
    return CollapsibleSection(
      icon: Icons.contact_phone_outlined,
      title: 'Personal & contact',
      summary: a.mobile == null ? a.email : '+63 ${a.mobile}',
      children: [
        InfoRow(icon: Icons.phone_iphone_rounded, label: 'Mobile', value: a.mobile == null ? '—' : '+63 ${a.mobile}'),
        InfoRow(icon: Icons.mail_outline_rounded, label: 'Email', value: a.email),
        if (a.fullAddress.isNotEmpty) InfoRow(icon: Icons.home_outlined, label: 'Home address', value: a.fullAddress),
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
                  icon: const Icon(Icons.support_agent_rounded, size: 18),
                  label: const Text('Call station'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _security() => CollapsibleSection(
        icon: Icons.shield_outlined,
        title: 'Security',
        summary: 'Password and sign-in',
        children: [
          InfoRow(
            icon: Icons.password_rounded,
            label: 'Password',
            value: 'Change password',
            onTap: () => showChangePassword(context),
          ),
        ],
      );
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
                if (a.company != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.business_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text('${a.company!.name} rider',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
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
    AppToast.success(context, 'Password changed. Other phones were signed out.');
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
                  Text(_error!, style: AppTextStyles.bodyStrong.copyWith(color: AppColors.errorStrong)),
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
  if (days < 0) return const TagChip.error(label: 'Expired');
  if (days <= 30) return TagChip.warning(label: days == 0 ? 'Expires today' : 'Expires in $days d');
  return const TagChip.success(label: 'Valid');
}

String _longDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _title(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
