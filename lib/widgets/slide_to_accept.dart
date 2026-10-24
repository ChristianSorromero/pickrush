import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';

/// Coral "Slide to Accept" bar. Sliding past 85% calls [onSubmit]; the knob
/// springs back if the call fails, so a pocket tap can never accept a batch.
class SlideToAccept extends StatefulWidget {
  const SlideToAccept({
    super.key,
    required this.onSubmit,
    this.label = 'Slide to Accept',
    this.enabled = true,
  });

  final String label;

  /// Greyed out and not draggable (e.g. still too far from the stop).
  final bool enabled;

  /// Return normally on success; throw to reset the slider.
  final Future<void> Function() onSubmit;

  @override
  State<SlideToAccept> createState() => _SlideToAcceptState();
}

class _SlideToAcceptState extends State<SlideToAccept> {
  static const _height = 56.0;
  static const _knob = 44.0;
  static const _pad = 6.0;

  double _dx = 0;
  bool _busy = false;

  Future<void> _release(double max) async {
    if (_dx < max * 0.85) {
      setState(() => _dx = 0);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _dx = max;
      _busy = true;
    });
    try {
      await widget.onSubmit();
    } catch (_) {
      if (mounted) setState(() => _dx = 0);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final max = c.maxWidth - _knob - _pad * 2;
      final progress = max <= 0 ? 0.0 : (_dx / max).clamp(0.0, 1.0);
      final active = widget.enabled && !_busy;
      return Container(
        height: _height,
        decoration: BoxDecoration(
          color: widget.enabled ? AppColors.primary : AppColors.border,
          borderRadius: AppRadius.pillAll,
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Center(
              child: Opacity(
                opacity: 1 - progress,
                child: Text(widget.label,
                    style: AppTextStyles.button.copyWith(
                        color: widget.enabled ? Colors.white : AppColors.textMuted)),
              ),
            ),
            AnimatedPositioned(
              duration: Duration(milliseconds: _dx == 0 ? 200 : 0),
              left: _pad + _dx,
              child: GestureDetector(
                onHorizontalDragUpdate: !active
                    ? null
                    : (d) => setState(
                        () => _dx = (_dx + d.delta.dx).clamp(0.0, max)),
                onHorizontalDragEnd: !active ? null : (_) => _release(max),
                child: Container(
                  height: _knob,
                  width: _knob,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        )
                      : Icon(
                          widget.enabled ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
                          color: widget.enabled ? AppColors.primary : AppColors.textMuted,
                          size: widget.enabled ? 28 : 20),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
