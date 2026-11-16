import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/wallet_models.dart';
import 'package:rider_app/riderpages/payslips_screen.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/icon_tile.dart';
import 'package:rider_app/widgets/section_card.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';
import 'package:rider_app/widgets/app_feedback.dart';

/// ₱240.00, or −₱85.00 for a negative balance.
String signedPeso(double v) => v < 0 ? '−${FormatUtils.peso(-v)}' : FormatUtils.peso(v);

String shortDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}';
}

/// The wallet: what the rider can withdraw now, the payslip waiting for the
/// station, and this week's pay so far. [onChanged] reloads the page after a
/// withdrawal.
class WalletCard extends StatefulWidget {
  const WalletCard({super.key, required this.wallet, required this.onChanged});
  final WalletSummary wallet;
  final Future<void> Function() onChanged;

  @override
  State<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<WalletCard> {
  bool _busy = false;

  Future<void> _withdraw() async {
    final w = widget.wallet;
    final amount = await showDialog<double>(context: context, builder: (_) => _WithdrawDialog(wallet: w));
    if (amount == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final (message, _) = await riderTasks.withdraw(amount);
      if (!mounted) return;
      AppToast.success(context, message);
      await widget.onChanged();
    } on TaskException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wallet;
    final canWithdraw = w.available > 0 && w.payout != null;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.account_balance_wallet_outlined, size: 36),
              AppSpacing.gapMd,
              Expanded(child: Text('WALLET', style: AppTextStyles.overline)),
              if (w.payout != null) Text('${w.payout!.label} ${w.payout!.account}', style: AppTextStyles.caption),
            ],
          ),
          AppSpacing.gapMd,
          Text('Available to withdraw', style: AppTextStyles.caption),
          Text(signedPeso(w.available),
              style: AppTextStyles.display.copyWith(color: w.available < 0 ? AppColors.warning : null)),
          if (w.available < 0)
            Text('Deductions were more than your pay. This comes off your next payslip.',
                style: AppTextStyles.caption.copyWith(color: AppColors.warning)),
          AppSpacing.gapMd,
          AppButton(
            label: 'Withdraw',
            onPressed: canWithdraw && !_busy ? _withdraw : null,
            isLoading: _busy,
          ),
          if (w.payout == null) ...[
            const SizedBox(height: 4),
            Text('No payout account on file. Ask your station manager to add your GCash, Maya or bank.',
                style: AppTextStyles.caption),
          ],
          AppSpacing.gapMd,
          if (w.awaitingRelease != 0)
            InfoRow(
              icon: Icons.hourglass_top_rounded,
              label: 'Last week · waiting for release',
              value: signedPeso(w.awaitingRelease),
              trailing: const TagChip.warning(label: 'By Tuesday'),
            ),
          InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'This week so far${w.closesAt != null ? ' · cutoff ${shortDate(w.closesAt!)}' : ''}',
            value: signedPeso(w.thisWeekNet),
          ),
          if (w.disputed > 0)
            InfoRow(
              icon: Icons.gavel_rounded,
              label: 'Disputed, waiting for your station',
              value: FormatUtils.peso(w.disputed),
            ),
          InfoRow(
            icon: Icons.receipt_long_outlined,
            label: 'Payslips',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayslipsScreen())),
          ),
        ],
      ),
    );
  }
}

class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog({required this.wallet});
  final WalletSummary wallet;

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  late final _amount = TextEditingController(text: widget.wallet.available.toStringAsFixed(2));

  double? get _value {
    final v = double.tryParse(_amount.text.replaceAll(',', '').trim());
    return v == null || v < 1 || v > widget.wallet.available + 0.001 ? null : v;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wallet;
    return AlertDialog(
      title: const Text('Withdraw'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Up to ${FormatUtils.peso(w.available)}, to your ${w.payout!.label} ${w.payout!.account}.',
              style: AppTextStyles.body),
          AppSpacing.gapMd,
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixText: '₱ ', hintText: '0.00'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _amount.text = w.available.toStringAsFixed(2)),
              child: const Text('All'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: _value == null ? null : () => Navigator.pop(context, _value),
          child: const Text('Withdraw'),
        ),
      ],
    );
  }
}

/// Deductions still open: the rider can dispute one until its payslip is released.
class DeductionsCard extends StatelessWidget {
  const DeductionsCard({super.key, required this.deductions, required this.onChanged});
  final List<WalletDeduction> deductions;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Deductions',
      children: [for (final d in deductions) DeductionRow(deduction: d, onChanged: onChanged)],
    );
  }
}

class DeductionRow extends StatefulWidget {
  const DeductionRow({super.key, required this.deduction, this.onChanged});
  final WalletDeduction deduction;

  /// Null on a released payslip: nothing left to dispute.
  final Future<void> Function()? onChanged;

  @override
  State<DeductionRow> createState() => _DeductionRowState();
}

class _DeductionRowState extends State<DeductionRow> {
  bool _busy = false;

  Future<void> _dispute() async {
    final reason = await _askReason();
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final (message, _) = await riderTasks.disputeDeduction(widget.deduction.id, reason);
      if (!mounted) return;
      AppToast.success(context, message);
      await widget.onChanged?.call();
    } on TaskException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askReason() {
    final note = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Dispute this deduction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Say why it is wrong. It stays off your payslip until your station manager decides.',
                  style: AppTextStyles.body),
              AppSpacing.gapMd,
              TextField(
                controller: note,
                autofocus: true,
                maxLength: 500,
                onChanged: (_) => setDialog(() {}),
                decoration: const InputDecoration(hintText: 'e.g. It was already broken when I picked it up'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: note.text.trim().length < 5 ? null : () => Navigator.pop(context, note.text.trim()),
              child: const Text('Dispute'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.deduction;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: d.kind == 'shortage' ? Icons.payments_outlined : Icons.inventory_2_outlined,
            size: 36,
            color: AppColors.warning,
            background: AppColors.warningSoft,
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text([d.label, if (d.trackingNo != null) d.trackingNo!].join(' · '), style: AppTextStyles.bodyStrong),
                Text([if (d.at != null) shortDate(d.at!), d.reason].join(' · '), style: AppTextStyles.caption),
                if (d.isDisputed && d.disputeReason != null)
                  Text('You said: ${d.disputeReason}', style: AppTextStyles.caption),
                if (d.decisionNote != null && !d.isDisputed)
                  Text('Station: ${d.decisionNote}', style: AppTextStyles.caption),
                if (d.canDispute && widget.onChanged != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: _busy ? null : _dispute, child: const Text('Dispute')),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('−${FormatUtils.peso(d.amount)}', style: AppTextStyles.bodyStrong.copyWith(color: AppColors.warning)),
              if (d.isDisputed) ...[
                const SizedBox(height: 4),
                const TagChip.muted(label: 'Disputed'),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The latest withdrawals (simulated payouts).
class WithdrawalsCard extends StatelessWidget {
  const WithdrawalsCard({super.key, required this.withdrawals});
  final List<Withdrawal> withdrawals;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Withdrawals',
      children: [
        for (final w in withdrawals)
          InfoRow(
            icon: Icons.north_east_rounded,
            label: [if (w.at != null) shortDate(w.at!), w.reference].join(' · '),
            value: '−${FormatUtils.peso(w.amount)}',
            trailing: const TagChip.success(label: 'Paid'),
          ),
      ],
    );
  }
}
