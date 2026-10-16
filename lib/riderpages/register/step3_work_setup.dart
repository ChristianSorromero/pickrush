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
  final _model = TextEditingController();
  final _plate = TextEditingController();

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
    _model.dispose();
    _plate.dispose();
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
      ..vehicleType = _type
      ..vehicleModel = _model.text.trim()
      ..plateNumber = _plate.text.trim().toUpperCase();

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
            const RegisterSectionHeader('Specifications'),
            AppSpacing.gapLg,
            RegisterLabeledField(
              label: 'Vehicle Make & Model',
              child: TextFormField(
                controller: _model,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: AppTextStyles.bodyStrong,
                decoration:
                    registerInputDecoration('e.g. Honda Click 125i'),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Required' : null,
              ),
            ),
            AppSpacing.gapLg,
            RegisterLabeledField(
              label: 'Plate Number / MV File Number',
              child: TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                style: AppTextStyles.bodyStrong,
                decoration: registerInputDecoration('e.g. ABC 1234'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (_type != null &&
                      !_type!.needsPlate &&
                      value.isEmpty) return null;
                  return value.length < 3 ? 'Required' : null;
                },
              ),
            ),
            AppSpacing.gapLg,
            _InfoNotice(
              "Make sure the plate number matches your vehicle's physical "
              'plate. This will be verified during the background check.',
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
    Widget card(VehicleType t) => Expanded(
          child: _VehicleTypeCard(
            type: t,
            selected: value == t,
            onTap: () => onChanged(t),
          ),
        );

    return Column(
      children: [
        Row(children: [
          card(VehicleType.motorcycle),
          AppSpacing.gapMd,
          card(VehicleType.car),
        ]),
        AppSpacing.gapMd,
        Row(children: [
          card(VehicleType.tricycle),
          AppSpacing.gapMd,
          card(VehicleType.bicycleOther),
        ]),
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
    VehicleType.car: Icons.directions_car_rounded,
    VehicleType.tricycle: Icons.electric_rickshaw_rounded,
    VehicleType.bicycleOther: Icons.pedal_bike_rounded,
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
          height: 96,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      child: Icon(
                        _icons[type],
                        size: 20,
                        color: selected
                            ? AppColors.surface
                            : AppColors.textMuted,
                      ),
                    ),
                    AppSpacing.gapSm,
                    Text(
                      selected
                          ? type.label
                          : type.label.toUpperCase(),
                      style: selected
                          ? AppTextStyles.bodyStrong
                              .copyWith(fontWeight: FontWeight.w800)
                          : AppTextStyles.overline.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.check_circle_rounded,
                      size: 18, color: AppColors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoNotice extends StatelessWidget {
  const _InfoNotice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.mdAll,
        border:
            Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_rounded,
                size: 16, color: AppColors.primaryDark),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                height: 1.4,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
