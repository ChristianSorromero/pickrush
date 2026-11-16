import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/services/scan_feedback.dart';

/// The waybill viewfinder used by every scanner in the app: back camera,
/// coral corner frame, flashlight, and a plain message when the camera is off.
/// [onCode] gets each barcode / QR value read (same code is not repeated).
class ScanCamera extends StatefulWidget {
  const ScanCamera({super.key, required this.onCode, this.height = 260, this.dark = false});

  final ValueChanged<String> onCode;
  final double height;

  /// Darker frame for the bottom-sheet scanner.
  final bool dark;

  @override
  State<ScanCamera> createState() => _ScanCameraState();
}

class _ScanCameraState extends State<ScanCamera> {
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.code39],
  );

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.lgAll,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _camera,
              onDetect: (capture) {
                for (final code in capture.barcodes) {
                  final raw = code.rawValue;
                  if (raw != null && raw.trim().isNotEmpty) widget.onCode(raw);
                }
              },
              errorBuilder: (context, error) => Container(
                color: AppColors.textPrimary,
                padding: const EdgeInsets.all(AppSpacing.xl),
                alignment: Alignment.center,
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Camera access is off. Allow it in Settings, or enter the waybill number manually.'
                      : 'Camera unavailable. Enter the waybill number manually.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyStrong.copyWith(color: Colors.white),
                ),
              ),
            ),
            const IgnorePointer(child: _Frame()),
            const IgnorePointer(child: _ScanFlash()),
            Positioned(
              top: 10,
              right: 10,
              child: ValueListenableBuilder<MobileScannerState>(
                valueListenable: _camera,
                builder: (_, state, __) => IconButton.filled(
                  onPressed: state.torchState == TorchState.unavailable ? null : _camera.toggleTorch,
                  icon: Icon(state.torchState == TorchState.on
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.black54, foregroundColor: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Green (accepted) or red (refused) edge glow for a moment after each scan.
/// Starts with the beep; nothing waits for it.
class _ScanFlash extends StatefulWidget {
  const _ScanFlash();

  @override
  State<_ScanFlash> createState() => _ScanFlashState();
}

class _ScanFlashState extends State<_ScanFlash> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  bool _ok = true;
  int? _seen;

  @override
  void initState() {
    super.initState();
    _seen = ScanFeedback.last.value?.$2;
    ScanFeedback.last.addListener(_onScan);
  }

  void _onScan() {
    final v = ScanFeedback.last.value;
    if (v == null || v.$2 == _seen || !mounted) return;
    _seen = v.$2;
    setState(() => _ok = v.$1);
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    ScanFeedback.last.removeListener(_onScan);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _ok ? AppColors.success : AppColors.error;
    final reduced = AppMotion.reduced(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        // Quick rise, slower fade; a steady short flash under reduced motion.
        final t = _c.value;
        final a = !_c.isAnimating && t == 0
            ? 0.0
            : reduced
                ? (t < 1 ? 1.0 : 0.0)
                : (t < 0.2 ? t / 0.2 : 1 - (t - 0.2) / 0.8);
        if (a <= 0) return const SizedBox.expand();
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: a), width: 8),
            color: color.withValues(alpha: 0.18 * a),
          ),
          alignment: Alignment.center,
          child: Opacity(
            opacity: a,
            child: Icon(_ok ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 64, color: Colors.white),
          ),
        );
      },
    );
  }
}

/// The coral corners of the viewfinder.
class _Frame extends StatelessWidget {
  const _Frame();

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: AppColors.primary, width: 4);
    Widget corner(Border border) => Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(border: border),
        );
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Stack(
        children: [
          Align(alignment: Alignment.topLeft, child: corner(const Border(top: side, left: side))),
          Align(alignment: Alignment.topRight, child: corner(const Border(top: side, right: side))),
          Align(alignment: Alignment.bottomLeft, child: corner(const Border(bottom: side, left: side))),
          Align(alignment: Alignment.bottomRight, child: corner(const Border(bottom: side, right: side))),
          Center(child: Container(height: 1.5, color: AppColors.primary.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

/// "Enter waybill number" dialog. [accept] returns null when the code was
/// taken, otherwise the reason it was refused (shown under the field).
Future<void> showManualEntry(BuildContext context, Future<String?> Function(String code) accept) {
  final controller = TextEditingController();
  String? error;
  bool busy = false;
  return showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialog) => AlertDialog(
        title: const Text('Enter waybill number'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: 'e.g. PR2610240000011A', errorText: error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    setDialog(() => busy = true);
                    final problem = await accept(controller.text);
                    if (!context.mounted) return;
                    if (problem == null) {
                      Navigator.pop(context);
                    } else {
                      setDialog(() {
                        busy = false;
                        error = problem;
                      });
                    }
                  },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}

/// Waybill numbers compare without spaces, in capitals.
String normalizeWaybill(String raw) => raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
