import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/earnings_models.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/section_card.dart';

/// The station counted the cash the rider handed over. The rider confirms the
/// count, or rejects it and the station counts again with them. Until then
/// the rider gets no new deliveries. Shown on the delivery handover screen.
class CashCountConfirm extends StatefulWidget {
  const CashCountConfirm({super.key, required this.count, required this.onAnswered});
  final PendingCashCount count;
  final Future<void> Function() onAnswered;

  @override
  State<CashCountConfirm> createState() => _CashCountConfirmState();
}

class _CashCountConfirmState extends State<CashCountConfirm> {
  bool _busy = false;

  Future<void> _answer(Future<String> Function() request) async {
    setState(() => _busy = true);
    try {
      final message = await request();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await widget.onAnswered();
    } on TaskException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await _askReason();
    if (reason == null) return;
    await _answer(() => riderTasks.rejectCashCount(widget.count.id, reason));
  }

  Future<String?> _askReason() {
    final note = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('The count is wrong'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Say how much you handed over. The station will count the cash again with you, and HQ sees this report.',
                  style: AppTextStyles.body),
              AppSpacing.gapMd,
              TextField(
                controller: note,
                autofocus: true,
                maxLength: 500,
                onChanged: (_) => setDialog(() {}),
                decoration: const InputDecoration(hintText: 'e.g. I handed over ₱1,460, not ₱960'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: note.text.trim().length < 5 ? null : () => Navigator.pop(context, note.text.trim()),
              child: const Text('Reject count'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.count;
    final matches = c.difference == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${c.countedBy ?? 'The station'} counted the cash you handed over. Check it before you confirm.',
          style: AppTextStyles.body,
        ),
        AppSpacing.gapMd,
        InfoRow(icon: Icons.payments_outlined, label: 'Station counted', value: FormatUtils.peso(c.counted)),
        InfoRow(icon: Icons.calculate_outlined, label: 'You should hand over', value: FormatUtils.peso(c.expected)),
        if (c.payKept > 0)
          InfoRow(icon: Icons.wallet_outlined, label: 'Your pay, kept from the cash', value: FormatUtils.peso(c.payKept)),
        if (!matches) ...[
          AppSpacing.gapSm,
          Text(
            c.difference < 0
                ? 'The station counted ${FormatUtils.peso(-c.difference)} less than you should hand over. If you confirm, the hub manager settles the shortage with you.'
                : 'The station counted ${FormatUtils.peso(c.difference)} more than you should hand over.',
            style: AppTextStyles.caption.copyWith(color: AppColors.warning),
          ),
        ],
        AppSpacing.gapLg,
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Wrong count',
                variant: AppButtonVariant.outline,
                onPressed: _busy ? null : _reject,
              ),
            ),
            AppSpacing.gapMd,
            Expanded(
              child: AppButton(
                label: 'Confirm',
                isLoading: _busy,
                onPressed: () => _answer(() => riderTasks.confirmCashCount(c.id)),
              ),
            ),
          ],
        ),
        AppSpacing.gapSm,
        Text('You get no new deliveries until you answer.', style: AppTextStyles.caption),
      ],
    );
  }
}
