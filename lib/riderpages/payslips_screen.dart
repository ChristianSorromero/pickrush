import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/format_utils.dart';
import 'package:rider_app/models/wallet_models.dart';
import 'package:rider_app/riderpages/wallet_parts.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/section_card.dart';
import 'package:rider_app/widgets/surface_card.dart';
import 'package:rider_app/widgets/tag_chip.dart';

/// The rider's weekly payslips, newest first. Each week (Monday to Sunday)
/// closes on Sunday night; the station releases it by Tuesday.
class PayslipsScreen extends StatefulWidget {
  const PayslipsScreen({super.key});

  @override
  State<PayslipsScreen> createState() => _PayslipsScreenState();
}

class _PayslipsScreenState extends State<PayslipsScreen> {
  List<Payslip>? _payslips;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await riderTasks.payslips();
      if (mounted) {
        setState(() {
          _payslips = list;
          _error = null;
        });
      }
    } on TaskException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _payslips;
    return Scaffold(
      appBar: AppBar(title: const Text('Payslips')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
          children: [
            if (list == null)
              _Loading(error: _error, onRetry: _load)
            else if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: Text('Your first payslip comes after Sunday night\'s cutoff.',
                      textAlign: TextAlign.center, style: AppTextStyles.body),
                ),
              )
            else
              SectionCard(
                title: 'Weekly pay',
                children: [
                  for (final p in list)
                    InfoRow(
                      icon: Icons.receipt_long_outlined,
                      label: '${shortDate(p.weekStart)} – ${shortDate(p.weekEnd)}',
                      value: signedPeso(p.net),
                      trailing: p.isReleased
                          ? const TagChip.success(label: 'Released')
                          : const TagChip.warning(label: 'Waiting'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PayslipScreen(id: p.id))),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// One payslip: what each task paid and what was deducted.
class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key, required this.id});
  final int id;

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  Payslip? _payslip;
  String? _error;

  static const _kinds = {'pickup': 'Pickup', 'delivery': 'Delivery', 'return': 'Return'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await riderTasks.payslip(widget.id);
      if (mounted) {
        setState(() {
          _payslip = p;
          _error = null;
        });
      }
    } on TaskException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _payslip;
    return Scaffold(
      appBar: AppBar(title: Text(p == null ? 'Payslip' : 'Week of ${shortDate(p.weekStart)}')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
          children: [
            if (p == null)
              _Loading(error: _error, onRetry: _load)
            else ...[
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${shortDate(p.weekStart)} – ${shortDate(p.weekEnd)}', style: AppTextStyles.overline),
                        ),
                        p.isReleased
                            ? TagChip.success(label: 'Released${p.releasedAt != null ? ' ${shortDate(p.releasedAt!)}' : ''}')
                            : const TagChip.warning(label: 'Released by Tuesday'),
                      ],
                    ),
                    AppSpacing.gapMd,
                    Text('Net pay', style: AppTextStyles.caption),
                    Text(signedPeso(p.net), style: AppTextStyles.display),
                    AppSpacing.gapMd,
                    InfoRow(
                      icon: Icons.inventory_2_outlined,
                      label: '${p.pickups} pickups · ${p.deliveries} deliveries · ${p.returns} returns',
                      value: FormatUtils.peso(p.earned),
                    ),
                    InfoRow(
                      icon: Icons.remove_circle_outline,
                      label: 'Deductions',
                      value: p.deductions > 0 ? '−${FormatUtils.peso(p.deductions)}' : '—',
                    ),
                  ],
                ),
              ),
              if (p.deductionItems.isNotEmpty) ...[
                AppSpacing.gapXl,
                SectionCard(
                  title: 'Deductions',
                  children: [
                    for (final d in p.deductionItems)
                      DeductionRow(deduction: d, onChanged: p.isReleased ? null : _load),
                  ],
                ),
              ],
              AppSpacing.gapXl,
              SectionCard(
                title: 'Earnings',
                children: [
                  for (final e in p.earnings)
                    InfoRow(
                      icon: e.kind == 'pickup' ? Icons.inventory_2_outlined : Icons.local_shipping_outlined,
                      label: [
                        _kinds[e.kind] ?? e.kind,
                        if (e.trackingNo != null) e.trackingNo!,
                        if (e.at != null) shortDate(e.at!),
                      ].join(' · '),
                      value: '+${FormatUtils.peso(e.amount)}',
                      valueColor: AppColors.success,
                    ),
                ],
              ),
              AppSpacing.gapLg,
            ],
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.error, required this.onRetry});
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: error == null
            ? const CircularProgressIndicator(color: AppColors.primary)
            : Column(
                children: [
                  Text(error!, textAlign: TextAlign.center, style: AppTextStyles.body),
                  AppSpacing.gapLg,
                  AppButton(label: 'Try again', onPressed: onRetry, expand: false),
                ],
              ),
      ),
    );
  }
}
