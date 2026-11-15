import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/services/auth_service.dart';
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

  List<LogisticsCompany> _companies = const [];
  late LogisticsCompany? _company = widget.data.company;
  List<Hub> _hubs = const [];
  late Hub? _hub = widget.data.hub;
  late VehicleType? _type = widget.data.vehicleType;

  bool _loadingCompanies = false;
  bool _loadingHubs = false;
  HubScope? _scope;
  String? _hubError;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  /// Companies taking riders near the address. The default company is pre-selected unless the
  /// rider already chose one (going back, or resubmitting).
  Future<void> _loadCompanies() async {
    setState(() {
      _loadingCompanies = true;
      _hubError = null;
    });
    try {
      final companies = await companyService.fetchNearby(
        cityCode: widget.data.city!.code,
        provinceCode: widget.data.province!.code,
      );
      if (!mounted) return;
      setState(() {
        _companies = companies;
        if (_company != null && !_companies.contains(_company)) _company = null;
        _company ??= _companies.where((c) => c.isDefault).firstOrNull ?? _companies.firstOrNull;
      });
      if (_company == null) {
        setState(() {
          _hubs = const [];
          _hub = null;
          _scope = HubScope.none;
        });
      } else {
        await _loadHubs();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _hubError = 'Could not load logistics companies. Please try again.');
    } finally {
      if (mounted) setState(() => _loadingCompanies = false);
    }
  }

  void _onCompanyChanged(LogisticsCompany? company) {
    if (company == null || company == _company) return;
    setState(() {
      _company = company;
      _hub = null;
      _hubs = const [];
    });
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
      final nearby = await hubService.fetchNearby(
        cityCode: widget.data.city!.code,
        provinceCode: widget.data.province!.code,
        companyId: _company!.id,
      );
      if (!mounted) return;
      setState(() {
        _hubs = nearby.hubs;
        _scope = nearby.scope;
        if (_hub != null && !_hubs.contains(_hub)) _hub = null;
        if (_hub == null && _hubs.length == 1) _hub = _hubs.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _hubError = 'Could not load stations. Please try again.');
    } finally {
      if (mounted) setState(() => _loadingHubs = false);
    }
  }

  void _onContinue() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    widget.data
      ..company = _company
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
                  message: _hubError!,
                  onRetry: _company == null ? _loadCompanies : _loadHubs),
              AppSpacing.gapLg,
            ],
            RegisterLabeledField(
              label: 'Logistics Company',
              child: RegisterDropdown<LogisticsCompany>(
                hint: 'Select a logistics company...',
                value: _company,
                items: _companies,
                labelOf: (c) => c.name,
                isLoading: _loadingCompanies,
                onChanged: _companies.isEmpty ? null : _onCompanyChanged,
              ),
            ),
            AppSpacing.gapSm,
            Text(
              'You ride for one company. Its station reviews your application.',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
            AppSpacing.gapLg,
            RegisterLabeledField(
              label: 'Station Hub',
              child: RegisterDropdown<Hub>(
                hint: 'Select your station...',
                value: _hub,
                items: _hubs,
                labelOf: (h) => h.name,
                isLoading: _loadingHubs || _loadingCompanies,
                onChanged:
                    _hubs.isEmpty ? null : (h) => setState(() => _hub = h),
              ),
            ),
            AppSpacing.gapSm,
            Text(
              switch (_scope) {
                HubScope.city =>
                  'Stations in ${widget.data.city?.name}. This station reviews your application.',
                HubScope.province =>
                  'No station in ${widget.data.city?.name} yet. Showing stations in ${widget.data.province?.name}.',
                HubScope.none => _company == null
                    ? 'No logistics company near your address is accepting riders yet. Please check again later.'
                    : 'No ${_company!.name} station near your address is accepting riders yet. Try another company or check again later.',
                null => 'The station you choose reviews your application.',
              },
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: _scope == HubScope.none ? AppColors.primaryDark : null,
              ),
            ),
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
        AppSpacing.gapLg,
        card(VehicleType.fourWheel),
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
    VehicleType.fourWheel: Icons.directions_car_rounded,
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