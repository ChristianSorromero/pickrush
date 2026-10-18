import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'register_shared.dart';
import 'step4_documents.dart';

class WorkSetupScreen extends StatefulWidget {
  const WorkSetupScreen({super.key, required this.data});
  final RegisterData data;

  @override
  State<WorkSetupScreen> createState() => _WorkSetupScreenState();
}

class _WorkSetupScreenState extends State<WorkSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  List<Hub> _hubs = const [];
  Hub? _hub;
  VehicleType? _type;

  bool _loadingHubs = false;
  bool _showingAllHubs = false;
  String? _hubError;

  @override
  void initState() {
    super.initState();
    _loadHubs();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadHubs() async {
    setState(() {
      _loadingHubs = true;
      _hubError = null;
    });
    try {
      final all = await hubService.fetchHubs();
      if (!mounted) return;
      final province = widget.data.province?.name;
      final nearby =
          all.where((h) => h.province == province).toList();
      setState(() {
        _hubs = nearby.isEmpty ? all : nearby;
        _showingAllHubs = nearby.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _hubError = 'Could not load hubs. Please try again.');
    } finally {
      if (mounted) setState(() => _loadingHubs = false);
    }
  }

  void _onContinue() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    widget.data
      ..hub = _hub
      ..vehicleType = _type;

    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => DocumentsScreen(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RegisterStepScaffold(
      step: 3,
      title: 'Work Setup',
      buttonLabel: 'Continue to Documents →',
      onContinue: _onContinue,
      onBack: () => Navigator.of(context).maybePop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hubError != null) ...[
              RegisterErrorBanner(
                  message: _hubError!, onRetry: _loadHubs),
              AppSpacing.gapLg,
            ],
            RegisterLabeledField(
              label: 'Preferred Hub',
              child: RegisterDropdown<Hub>(
                hint: 'Select a hub...',
                value: _hub,
                items: _hubs,
                labelOf: (h) => h.name,
                isLoading: _loadingHubs,
                isRequired: false,
                onChanged:
                    _hubs.isEmpty ? null : (h) => setState(() => _hub = h),
              ),
            ),
            if (_showingAllHubs) ...[
              AppSpacing.gapSm,
              Text(
                'No hubs in your province yet. Showing all hubs.',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
            AppSpacing.gapXl,
            RegisterSectionHeader(
              'Vehicle Type',
              trailing: Text('Required', style: AppTextStyles.caption),
            ),
            AppSpacing.gapLg,
            FormField<VehicleType>(
              validator: (_) =>
                  _type == null ? 'Please select a vehicle type' : null,
              builder: (state) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VehicleTypeGrid(
                    value: _type,
                    onChanged: (t) {
                      setState(() => _type = t);
                      state.didChange(t);
                    },
                  ),
                  if (state.hasError) ...[
                    AppSpacing.gapSm,
                    Text(
                      state.errorText!,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primaryDark),
                    ),
                  ],
                ],
              ),
            ),
            AppSpacing.gapXl,
          ],
        ),
      ),
    );
  }
}

class _VehicleTypeGrid extends StatelessWidget {
  const _VehicleTypeGrid(
      {required this.value, required this.onChanged});
  final VehicleType? value;
  final ValueChanged<VehicleType> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget card(VehicleType t) => _VehicleTypeCard(
          type: t,
          selected: value == t,
          onTap: () => onChanged(t),
        );

    // Stacked top-to-bottom, full width pero hindi sagad ang screen
    return Column(
      children: [
        card(VehicleType.motorcycle),
        AppSpacing.gapLg,
        card(VehicleType.tricycle),
      ],
    );
  }
}

class _VehicleTypeCard extends StatelessWidget {
  const _VehicleTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final VehicleType type;
  final bool selected;
  final VoidCallback onTap;

  static const _icons = {
    VehicleType.motorcycle: Icons.two_wheeler_rounded,
    VehicleType.tricycle: Icons.electric_rickshaw_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 120,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  child: Icon(
                    _icons[type],
                    size: 32,
                    color:
                        selected ? AppColors.surface : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    type.label,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 24,
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}