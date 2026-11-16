import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/riderpages/register/register_shared.dart';
import 'package:rider_app/services/auth_service.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/app_feedback.dart';

/// Sending a renewed driver's license or OR/CR from Account, any time. The
/// station hub manager approves it; until then the one on file stays valid.
/// Pops the updated account when sent.
class DocumentUpdateScreen extends StatefulWidget {
  const DocumentUpdateScreen({super.key, required this.type, this.licenseNo});

  /// drivers_license or or_cr.
  final String type;

  /// The license number on file, to start from.
  final String? licenseNo;

  bool get isLicense => type == 'drivers_license';

  @override
  State<DocumentUpdateScreen> createState() => _DocumentUpdateScreenState();
}

class _DocumentUpdateScreenState extends State<DocumentUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final _licenseNoCtrl = TextEditingController(text: widget.licenseNo ?? '');
  final _expiryCtrl = TextEditingController();

  String? _front;
  String? _back;
  final _files = <String>[];
  bool _sending = false;
  double _progress = 0;
  String? _error;

  static const _maxFileBytes = 8 * 1024 * 1024;

  @override
  void dispose() {
    _licenseNoCtrl.dispose();
    _expiryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto({required bool front}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await _picker.pickImage(source: source, maxWidth: 1800, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() {
      front ? _front = file.path : _back = file.path;
      _error = null;
    });
  }

  Future<void> _attachFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || !mounted) return;
    setState(() {
      for (final f in result.files) {
        if (f.path != null && !_files.contains(f.path)) _files.add(f.path!);
      }
      _error = null;
    });
  }

  String? _checkFiles() {
    final paths = widget.isLicense ? [_front, _back] : _files;
    if (widget.isLicense && (_front == null || _back == null)) return 'Add photos of both sides of your license.';
    if (!widget.isLicense && _files.isEmpty) return 'Attach your new OR/CR.';
    if (!widget.isLicense && _files.length > kMaxOrcrFiles) return 'Attach up to $kMaxOrcrFiles files only.';
    for (final p in paths.whereType<String>()) {
      if (File(p).lengthSync() > _maxFileBytes) return 'A file is larger than 8 MB. Use a smaller photo or file.';
    }
    return null;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final problem = _checkFiles();
    if (problem != null) return setState(() => _error = problem);

    setState(() {
      _sending = true;
      _progress = 0;
      _error = null;
    });
    try {
      final (message, account) = await authService.renewDocument(
        type: widget.type,
        expiry: parseExpiryInput(_expiryCtrl.text)!,
        licenseNo: widget.isLicense ? _licenseNoCtrl.text.trim() : null,
        front: _front,
        back: _back,
        files: _files,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      AppToast.success(context, message);
      Navigator.of(context).pop(account);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLicense = widget.isLicense;
    return Scaffold(
      appBar: AppBar(
        title: Text(isLicense ? "Renew driver's license" : 'Renew OR/CR', style: AppTextStyles.h2),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
            children: [
              Text(
                'Your station checks it before it replaces the one on file. '
                'Until then, the one on file stays valid.',
                style: AppTextStyles.body,
              ),
              AppSpacing.gapXl,
              if (isLicense) ...[
                Row(
                  children: [
                    Expanded(child: _PhotoTile(label: 'Front', path: _front, onTap: () => _pickPhoto(front: true))),
                    AppSpacing.gapMd,
                    Expanded(child: _PhotoTile(label: 'Back', path: _back, onTap: () => _pickPhoto(front: false))),
                  ],
                ),
                AppSpacing.gapXl,
                RegisterLabeledField(
                  label: "Driver's License No.",
                  child: TextFormField(
                    controller: _licenseNoCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [LicenseNoFormatter()],
                    validator: validateLicenseNo,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    style: AppTextStyles.bodyStrong,
                    decoration: registerInputDecoration('A00-00-000000'),
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _attachFiles,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('Attach OR/CR (photo or PDF)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  ),
                ),
                for (final p in _files)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.textSecondary),
                    title: Text(p.split(Platform.pathSeparator).last, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyStrong),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Remove',
                      onPressed: () => setState(() => _files.remove(p)),
                    ),
                  ),
              ],
              AppSpacing.gapLg,
              RegisterLabeledField(
                label: isLicense ? 'Expiration Date' : 'Registration expiry (on the OR)',
                child: TextFormField(
                  controller: _expiryCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ExpiryDateFormatter()],
                  validator: isLicense ? validateLicenseExpiry : validateOrcrExpiry,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  style: AppTextStyles.bodyStrong,
                  decoration: registerInputDecoration('YYYY-MM-DD'),
                ),
              ),
              if (_error != null) ...[
                AppSpacing.gapLg,
                RegisterErrorBanner(message: _error!),
              ],
              AppSpacing.gapXl,
              if (_sending && _progress > 0 && _progress < 1) ...[
                LinearProgressIndicator(value: _progress, color: AppColors.primary, backgroundColor: AppColors.border),
                AppSpacing.gapMd,
              ],
              AppButton(label: 'Send to my station', isLoading: _sending, onPressed: _sending ? null : _send),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.label, required this.path, required this.onTap});
  final String label;
  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.3,
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: path == null ? AppColors.border : AppColors.success),
        ),
        child: InkWell(
          onTap: onTap,
          child: path == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
                    AppSpacing.gapSm,
                    Text(label.toUpperCase(), style: AppTextStyles.overline),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(path!), fit: BoxFit.cover),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.success, borderRadius: AppRadius.mdAll),
                        child: Text(label.toUpperCase(),
                            style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
