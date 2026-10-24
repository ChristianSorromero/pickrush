import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/services/address_service.dart';
import 'register_shared.dart';
import 'step2_account.dart';
import 'step3_work_setup.dart';

class RegisterScreen extends StatefulWidget {
  /// [initial] refills the form when a rejected rider resubmits.
  const RegisterScreen({super.key, this.initial});
  final RegisterData? initial;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final RegisterData _data = widget.initial ?? RegisterData();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _dob = TextEditingController();
  final _mobile = TextEditingController();
  final _street = TextEditingController();

  final _psgc = PsgcService();

  List<PsgcPlace> _provinces = const [];
  List<PsgcPlace> _cities = const [];
  List<PsgcPlace> _barangays = const [];
  PsgcPlace? _province;
  PsgcPlace? _city;
  PsgcPlace? _barangay;

  bool _loadingProvinces = false;
  bool _loadingCities = false;
  bool _loadingBarangays = false;
  String? _addressError;
  VoidCallback? _retry;

  @override
  void initState() {
    super.initState();
    _firstName.text = _data.firstName;
    _lastName.text = _data.lastName;
    _mobile.text = _data.mobile;
    _street.text = _data.street;
    if (_data.birthDate != null) _dob.text = formatRegisterDate(_data.birthDate!);
    _province = _data.province;
    _city = _data.city;
    _barangay = _data.barangay;

    _loadProvinces();
    if (_province != null) _loadCities(_province!);
    if (_city != null) _loadBarangays(_city!);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _dob.dispose();
    _mobile.dispose();
    _street.dispose();
    _psgc.dispose();
    super.dispose();
  }

  void _fail(Object e, VoidCallback retry) {
    if (!mounted) return;
    setState(() {
      _addressError = e is PsgcException
          ? e.message
          : 'Could not load addresses. Please try again.';
      _retry = retry;
    });
  }

  Future<void> _loadProvinces() async {
    setState(() {
      _loadingProvinces = true;
      _addressError = null;
    });
    try {
      final list = await _psgc.provinces();
      if (!mounted) return;
      setState(() => _provinces = list);
    } catch (e) {
      _fail(e, _loadProvinces);
    } finally {
      if (mounted) setState(() => _loadingProvinces = false);
    }
  }

  Future<void> _loadCities(PsgcPlace province) async {
    setState(() {
      _loadingCities = true;
      _addressError = null;
    });
    try {
      final list = await _psgc.citiesOf(province);
      if (!mounted || _province != province) return;
      setState(() => _cities = list);
    } catch (e) {
      if (_province == province) _fail(e, () => _loadCities(province));
    } finally {
      if (mounted && _province == province) {
        setState(() => _loadingCities = false);
      }
    }
  }

  Future<void> _loadBarangays(PsgcPlace city) async {
    setState(() {
      _loadingBarangays = true;
      _addressError = null;
    });
    try {
      final list = await _psgc.barangaysOf(city);
      if (!mounted || _city != city) return;
      setState(() => _barangays = list);
    } catch (e) {
      if (_city == city) _fail(e, () => _loadBarangays(city));
    } finally {
      if (mounted && _city == city) {
        setState(() => _loadingBarangays = false);
      }
    }
  }

  void _onProvinceChanged(PsgcPlace? p) {
    if (p == null) return;
    setState(() {
      _province = p;
      _city = null;
      _barangay = null;
      _cities = const [];
      _barangays = const [];
    });
    _loadCities(p);
  }

  void _onCityChanged(PsgcPlace? c) {
    if (c == null) return;
    setState(() {
      _city = c;
      _barangay = null;
      _barangays = const [];
    });
    _loadBarangays(c);
  }

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final latest = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _data.birthDate ?? latest,
      firstDate: DateTime(1940),
      lastDate: latest,
      helpText: 'Date of birth',
    );
    if (picked != null) {
      setState(() {
        _data.birthDate = picked;
        _dob.text = formatRegisterDate(picked);
      });
    }
  }

  void _onContinue() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    _data
      ..firstName = _firstName.text.trim()
      ..lastName = _lastName.text.trim()
      ..mobile = _mobile.text.trim()
      ..province = _province
      ..city = _city
      ..barangay = _barangay
      ..street = _street.text.trim();

    // A resubmitting rider already has a verified email and password.
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => _data.isResubmission
              ? WorkSetupScreen(data: _data)
              : AccountCreationScreen(data: _data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RegisterStepScaffold(
      step: 1,
      title: 'Personal Details',
      buttonLabel: _data.isResubmission
          ? 'Continue to Work Setup'
          : 'Continue to Account Creation',
      onContinue: _onContinue,
      onBack: () => Navigator.of(context).maybePop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide your legal information as it appears on your '
              'government-issued ID.',
              style: AppTextStyles.body.copyWith(fontSize: 13),
            ),
            AppSpacing.gapXl,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RegisterLabeledField(
                    label: 'First Name',
                    child: TextFormField(
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: AppTextStyles.bodyStrong,
                      decoration: registerInputDecoration('Juan'),
                      validator: _validateName,
                    ),
                  ),
                ),
                AppSpacing.gapMd,
                Expanded(
                  child: RegisterLabeledField(
                    label: 'Last Name',
                    child: TextFormField(
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: AppTextStyles.bodyStrong,
                      decoration: registerInputDecoration('Dela Cruz'),
                      validator: _validateName,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.gapLg,
            RegisterLabeledField(
              label: 'Date of Birth',
              child: TextFormField(
                controller: _dob,
                readOnly: true,
                onTap: _pickBirthDate,
                style: AppTextStyles.bodyStrong,
                decoration: registerInputDecoration(
                  'Select date',
                  suffixIcon: const Icon(Icons.calendar_today_outlined,
                      size: 18, color: AppColors.textSecondary),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
            ),
            AppSpacing.gapLg,
            RegisterLabeledField(
              label: 'Mobile Number',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('+63', style: AppTextStyles.bodyStrong),
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: TextFormField(
                      controller: _mobile,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: AppTextStyles.bodyStrong,
                      decoration: registerInputDecoration('917 123 4567'),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Required';
                        if (value.length != 10 || !value.startsWith('9')) {
                          return 'Enter a valid 10-digit number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapXl,
            const RegisterSectionHeader('Residential Address'),
            AppSpacing.gapLg,
            if (_addressError != null) ...[
              RegisterErrorBanner(
                  message: _addressError!, onRetry: _retry),
              AppSpacing.gapLg,
            ],
            RegisterDropdown<PsgcPlace>(
              hint: 'Select province',
              value: _province,
              items: _provinces,
              labelOf: (p) => p.name,
              isLoading: _loadingProvinces,
              onChanged: _provinces.isEmpty ? null : _onProvinceChanged,
            ),
            AppSpacing.gapLg,
            RegisterDropdown<PsgcPlace>(
              key: ValueKey('city-${_province?.code}'),
              hint: 'Select city / municipality',
              value: _city,
              items: _cities,
              labelOf: (p) => p.name,
              isLoading: _loadingCities,
              onChanged: _cities.isEmpty ? null : _onCityChanged,
            ),
            AppSpacing.gapLg,
            RegisterDropdown<PsgcPlace>(
              key: ValueKey('brgy-${_province?.code}-${_city?.code}'),
              hint: 'Select barangay',
              value: _barangay,
              items: _barangays,
              labelOf: (p) => p.name,
              isLoading: _loadingBarangays,
              onChanged: _barangays.isEmpty
                  ? null
                  : (v) => setState(() => _barangay = v),
            ),
            AppSpacing.gapLg,
            RegisterLabeledField(
              label: 'House Number, Street, Building',
              child: TextFormField(
                controller: _street,
                minLines: 3,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyStrong,
                decoration: registerInputDecoration(
                    'e.g. Unit 402, Green Tower, Katipunan Ave.'),
                validator: (v) =>
                    (v == null || v.trim().length < 5) ? 'Required' : null,
              ),
            ),
            AppSpacing.gapXl,
          ],
        ),
      ),
    );
  }

  String? _validateName(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Required';
    if (value.length < 2) return 'Too short';
    return null;
  }
}
