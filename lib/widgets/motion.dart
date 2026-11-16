import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import 'package:rider_app/app_spacing.dart';

/// Shared motion pieces, ported from Picksell Buyer's `ps_motion.dart` so
/// both apps move the same way (see [AppMotion]).

/// Press feedback: shrinks [child] slightly while a finger is down. Listens
/// to raw pointers, so it never delays or competes with the child's own tap
/// and a drag past the touch slop releases it.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true, this.scale = 0.97});

  final Widget child;
  final bool enabled;

  /// Pressed size; cards use a gentler 0.98.
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  Offset? _down;

  void _set(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || AppMotion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (e) {
        _down = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        if (_down != null && (e.position - _down!).distance > kTouchSlop) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: AppMotion.press,
        curve: _pressed ? AppMotion.exit : AppMotion.enter,
        child: widget.child,
      ),
    );
  }
}

/// Cross-fades [child] with a short rise when [value] changes — counters
/// ("3 of 7 scanned"), totals, status labels.
class ValueSwap extends StatelessWidget {
  const ValueSwap({super.key, required this.value, required this.child, this.alignment = Alignment.centerLeft});

  final Object? value;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.duration(context, AppMotion.small),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, if (current != null) current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(value), child: child),
    );
  }
}

/// Fades [child] in with a small rise the first time it builds: content
/// replacing a loading state. Not for every row of a list.
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.offset = 12});

  final Widget child;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final d = AppMotion.duration(context, AppMotion.content);
    if (d == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: d,
      curve: AppMotion.enter,
      child: child,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * offset), child: child),
      ),
    );
  }
}

/// Android page transition (same as Buyer): the new page slides a short way
/// in from the right while fading; the page under it drifts left.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Duration get reverseTransitionDuration => AppMotion.pageBack;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return FadeTransition(opacity: animation, child: child);
    final enter = CurvedAnimation(parent: animation, curve: AppMotion.enter, reverseCurve: AppMotion.exit);
    return SlideTransition(
      position: Tween(begin: Offset.zero, end: const Offset(-0.05, 0))
          .animate(CurvedAnimation(parent: secondaryAnimation, curve: AppMotion.change)),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.7, curve: Curves.easeOut)),
        child: SlideTransition(
          position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(enter),
          child: child,
        ),
      ),
    );
  }
}
