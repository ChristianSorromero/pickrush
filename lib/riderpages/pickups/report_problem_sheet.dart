import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/services/location_service.dart';
import 'package:rider_app/services/rider_task_service.dart';
import 'package:rider_app/widgets/app_button.dart';

/// "Report a problem": the station sees it on its dashboard with where the
/// rider is, and calls them back.
Future<void> showReportProblem(BuildContext context, int batchId) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (_) => _ReportSheet(batchId: batchId),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sent to your station. They will contact you.')));
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.batchId});
  final int batchId;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  List<Choice>? _problems;
  String? _type;
  final _note = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    riderTasks.options().then((o) {
      if (mounted) setState(() => _problems = o.riderProblems);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    GpsFix? fix;
    try {
      fix = await locationService.current();
    } catch (_) {
      // The report still goes out without a location.
    }
    try {
      await riderTasks.reportProblem(widget.batchId,
          type: _type!, note: _note.text.trim(), fix: fix);
      if (mounted) Navigator.of(context).pop(true);
    } on TaskException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsNote = _type == 'other' && _note.text.trim().isEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report a problem', style: AppTextStyles.h2.copyWith(fontSize: 18)),
              const SizedBox(height: 2),
              Text('Your station gets this with your location.',
                  style: AppTextStyles.caption),
              AppSpacing.gapLg,
              if (_problems == null && _error == null)
                const Center(child: CircularProgressIndicator(color: AppColors.primary))
              else if (_problems != null)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final p in _problems!)
                      ChoiceChip(
                        label: Text(p.label),
                        selected: _type == p.key,
                        onSelected: (on) => setState(() => _type = on ? p.key : null),
                        selectedColor: AppColors.primarySoft,
                      ),
                  ],
                ),
              AppSpacing.gapMd,
              TextField(
                controller: _note,
                maxLines: 2,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _type == 'other' ? 'What happened? (required)' : 'Details (optional)',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                ),
              ),
              if (_error != null)
                Text(_error!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark)),
              AppSpacing.gapSm,
              AppButton(
                label: 'Send to station',
                isLoading: _sending,
                onPressed: _type == null || needsNote ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
