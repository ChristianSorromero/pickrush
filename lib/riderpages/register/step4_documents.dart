import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'register_shared.dart';
import 'step5_review.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.data});
  final RegisterData data;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _picker = ImagePicker();
  String? _error;

  RegisterData get _d => widget.data;

  // ── Pickers ────────────────────────────────────────────────────────────────

  Future<void> _pickLicense({required bool front}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
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

    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1800,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() {
      if (front) {
        _d.licenseFrontPath = file.path;
      } else {
        _d.licenseBackPath = file.path;
      }
      _error = null;
    });
  }

  Future<void> _attachRegistration() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || !mounted) return;
    setState(() {
      for (final f in result.files) {
        if (f.path != null && !_d.registrationPaths.contains(f.path)) {
          _d.registrationPaths.add(f.path!);
        }
      }
      _error = null;
    });
  }

  void _onContinue() {
    if (_d.licenseFrontPath == null || _d.licenseBackPath == null) {
      setState(() => _error =
          "Please upload both sides of your driver's license.");
      return;
    }
    if (_d.registrationPaths.isEmpty) {
      setState(() => _error = 'Please attach your OR/CR.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReviewScreen(data: _d)),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RegisterStepScaffold(
      step: 4,
      title: 'Identity & Documents',
      buttonLabel: 'Proceed to Final Review  →',
      onContinue: _onContinue,
      onBack: () => Navigator.of(context).maybePop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RegisterSectionHeader(
            "Professional Driver's License",
            trailing: Text('Clear photo required',
                style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ),
          AppSpacing.gapLg,
          Row(
            children: [
              Expanded(
                child: _PhotoSlot(
                  label: 'FRONT',
                  emptyLabel: 'FRONT VIEW',
                  path: _d.licenseFrontPath,
                  onTap: () => _pickLicense(front: true),
                ),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: _PhotoSlot(
                  label: 'BACK',
                  emptyLabel: 'BACK VIEW',
                  path: _d.licenseBackPath,
                  onTap: () => _pickLicense(front: false),
                ),
              ),
            ],
          ),
          AppSpacing.gapXl,
          const RegisterSectionHeader('Vehicle Registration (OR/CR)'),
          AppSpacing.gapLg,
          _DashedBox(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.description_outlined,
                            color: AppColors.textMuted),
                      ),
                      AppSpacing.gapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Official Receipt & Certificate of Registration',
                              style: AppTextStyles.bodyStrong
                                  .copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "If borrowed, upload the owner's authorization "
                              'letter together with the OR/CR.',
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 11, height: 1.3),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _attachRegistration,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.attach_file_rounded,
                                        size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ATTACH DOCUMENTS',
                                      style: AppTextStyles.link.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_d.registrationPaths.isNotEmpty) ...[
                    AppSpacing.gapMd,
                    for (final p in _d.registrationPaths)
                      _AttachedFileRow(
                        name: p.split(Platform.pathSeparator).last,
                        onRemove: () =>
                            setState(() => _d.registrationPaths.remove(p)),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            AppSpacing.gapLg,
            RegisterErrorBanner(message: _error!),
          ],
          AppSpacing.gapXl,
          const _GuidelinesCard(),
          AppSpacing.gapXl,
        ],
      ),
    );
  }
}

// ── License photo slot ───────────────────────────────────────────────────────

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.emptyLabel,
    required this.path,
    required this.onTap,
  });

  final String label;
  final String emptyLabel;
  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = path != null;
    return AspectRatio(
      aspectRatio: 1.3,
      child: GestureDetector(
        onTap: onTap,
        child: has
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(path!), fit: BoxFit.cover),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : _DashedBox(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 24, color: AppColors.primary),
                      const SizedBox(height: 6),
                      Text(
                        emptyLabel,
                        style: AppTextStyles.overline.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _AttachedFileRow extends StatelessWidget {
  const _AttachedFileRow({required this.name, required this.onRemove});
  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 12)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Guidelines ───────────────────────────────────────────────────────────────

class _GuidelinesCard extends StatelessWidget {
  const _GuidelinesCard();

  @override
  Widget build(BuildContext context) {
    Widget bullet(String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.check_circle_rounded,
                    size: 14, color: AppColors.success),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: AppTextStyles.caption
                        .copyWith(fontSize: 11, height: 1.3)),
              ),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'VERIFICATION GUIDELINES',
                style: AppTextStyles.overline.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          bullet('Documents must be original and currently valid '
              '(not expired).'),
          bullet('Ensure there is no glare from camera flash reflecting '
              'on the cards.'),
        ],
      ),
    );
  }
}

// ── Dashed border container ──────────────────────────────────────────────────

class _DashedBox extends StatelessWidget {
  const _DashedBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: AppColors.border,
        radius: 16,
        fill: AppColors.surface,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter(
      {required this.color, required this.radius, required this.fill});
  final Color color;
  final Color fill;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = fill);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.fill != fill || old.radius != radius;
}