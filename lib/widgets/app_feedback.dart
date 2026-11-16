import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/widgets/app_button.dart';
import 'package:rider_app/widgets/motion.dart';

enum ToastType { success, error, info }

/// Short, non-blocking result of an action. Replaces any toast showing.
/// Say "success" only after the server confirmed it.
class AppToast {
  AppToast._();

  static void show(BuildContext context, String message, {ToastType type = ToastType.info}) {
    final (icon, color) = switch (type) {
      ToastType.success => (Icons.check_circle_rounded, const Color(0xFF6FCF73)),
      ToastType.error => (Icons.error_rounded, const Color(0xFFF87171)),
      ToastType.info => (Icons.info_rounded, Colors.white70),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: Duration(seconds: type == ToastType.error ? 4 : 3),
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ));
  }

  static void success(BuildContext context, String message) => show(context, message, type: ToastType.success);
  static void error(BuildContext context, String message) => show(context, message, type: ToastType.error);
}

/// Yes/no confirmation in the app's style. Resolves to true only on confirm.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xl),
      actions: [
        Column(
          children: [
            AppButton(
              label: confirmLabel,
              variant: destructive ? AppButtonVariant.destructive : AppButtonVariant.primary,
              onPressed: () => Navigator.pop(context, true),
            ),
            AppSpacing.gapSm,
            AppButton(
              label: cancelLabel,
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ],
    ),
  );
  return ok == true;
}

/// The full-area states a screen can be in before it has content: loading
/// (a skeleton when the layout is known), failed to load, or empty.
class StateView extends StatelessWidget {
  const StateView.loading({super.key, this.skeleton})
      : icon = null,
        title = null,
        message = null,
        onRetry = null,
        offline = false;

  const StateView.error({super.key, required this.message, this.onRetry, this.offline = false})
      : icon = null,
        title = null,
        skeleton = null;

  const StateView.empty({super.key, required this.icon, required this.title, this.message})
      : onRetry = null,
        offline = false,
        skeleton = null;

  final IconData? icon;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final bool offline;
  final Widget? skeleton;

  bool get _isLoading => icon == null && message == null;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return skeleton ??
          const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator()));
    }
    final isError = icon == null;
    final shownIcon = isError ? (offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded) : icon!;
    final shownTitle = isError ? (offline ? 'You are offline' : 'Could not load') : title!;
    final tone = isError ? TaskTone.failed : TaskTone.muted;
    return FadeIn(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: tone.soft, shape: BoxShape.circle),
              child: Icon(shownIcon, size: 30, color: tone.color),
            ),
            AppSpacing.gapLg,
            Text(shownTitle, textAlign: TextAlign.center, style: AppTextStyles.h2),
            if (message != null) ...[
              AppSpacing.gapSm,
              Text(message!, textAlign: TextAlign.center, style: AppTextStyles.body),
            ],
            if (onRetry != null) ...[
              AppSpacing.gapXl,
              AppButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pulsing placeholder block; several in one [SkeletonGroup] pulse together.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, required this.height, this.radius = AppRadius.sm});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = _Pulse.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.surfaceMuted, AppColors.border, t),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonGroup extends StatefulWidget {
  const SkeletonGroup({super.key, required this.child});
  final Widget child;

  @override
  State<SkeletonGroup> createState() => _SkeletonGroupState();
}

class _SkeletonGroupState extends State<SkeletonGroup> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => _Pulse(value: _c.value, child: widget.child),
      );
}

class _Pulse extends InheritedWidget {
  const _Pulse({required this.value, required super.child});
  final double value;

  static double of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_Pulse>()?.value ?? 0;

  @override
  bool updateShouldNotify(_Pulse old) => old.value != value;
}

/// Skeleton for a list of task cards (title row, two lines).
class CardListSkeleton extends StatelessWidget {
  const CardListSkeleton({super.key, this.count = 3});
  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Skeleton(width: 90, height: 16), Spacer(), Skeleton(width: 70, height: 18)]),
                  SizedBox(height: 12),
                  Skeleton(width: 200, height: 12),
                  SizedBox(height: 8),
                  Skeleton(height: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Slim notice shown while the app's check-ins can't reach the server.
/// Driven by real poll results, never by a timer.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.visible, this.lastSyncAt});

  final bool visible;
  final DateTime? lastSyncAt;

  @override
  Widget build(BuildContext context) {
    final since = lastSyncAt == null ? '' : ' · last updated ${_ago(lastSyncAt!)}';
    return AnimatedSize(
      duration: AppMotion.duration(context, AppMotion.small),
      curve: AppMotion.change,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                color: AppColors.warningSoft,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Can't reach the server. Actions won't be saved until you're back online$since.",
                        style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    return '${d.inHours} h ago';
  }
}

/// One line under a screen that re-checks the server on a timer: when it last
/// heard back, or that it can't reach it. Driven by real request results.
class SyncStatus extends StatefulWidget {
  const SyncStatus({super.key, required this.lastSyncAt, required this.failing, this.label = 'Checking with the station'});

  final DateTime? lastSyncAt;
  final bool failing;
  final String label;

  @override
  State<SyncStatus> createState() => _SyncStatusState();
}

class _SyncStatusState extends State<SyncStatus> {
  late final Stream<int> _tick = Stream.periodic(const Duration(seconds: 5), (i) => i);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _tick,
      builder: (context, _) {
        final t = widget.lastSyncAt;
        final ago = t == null ? null : DateTime.now().difference(t);
        final when = ago == null
            ? 'not updated yet'
            : ago.inSeconds < 10
                ? 'updated just now'
                : ago.inMinutes < 1
                    ? 'updated ${ago.inSeconds} s ago'
                    : 'updated ${ago.inMinutes} min ago';
        final color = widget.failing ? AppColors.warning : AppColors.textMuted;
        return Semantics(
          liveRegion: widget.failing,
          child: Row(
            children: [
              Icon(widget.failing ? Icons.wifi_off_rounded : Icons.sync_rounded, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.failing ? "Can't reach the server · $when" : '${widget.label} · $when',
                  style: AppTextStyles.caption.copyWith(color: color, fontWeight: widget.failing ? FontWeight.w700 : null),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
