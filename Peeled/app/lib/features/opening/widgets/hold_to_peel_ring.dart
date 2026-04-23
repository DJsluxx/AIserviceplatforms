import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// Circular "press-and-hold" ring that fills as the user sustains contact.
///
/// Anti-cheat: a single tap will NEVER trigger a peel. The user must hold
/// for [holdDuration] (default 1.4 s) and every haptic tick signals that
/// contact is verified live on-device. If the finger lifts early, the
/// ring drains to zero in [releaseDuration] and no action fires.
///
/// [onCommit] fires exactly once per successful completion; the ring
/// then freezes at 100 % until the parent rebuilds with [enabled]=false.
class HoldToPeelRing extends StatefulWidget {
  const HoldToPeelRing({
    super.key,
    required this.accent,
    required this.enabled,
    required this.haptics,
    required this.onCommit,
    this.size = 220,
    this.holdDuration = const Duration(milliseconds: 1400),
    this.releaseDuration = const Duration(milliseconds: 260),
    this.child,
  });

  final Color accent;
  final bool enabled;
  final bool haptics;
  final VoidCallback onCommit;
  final double size;
  final Duration holdDuration;
  final Duration releaseDuration;
  final Widget? child;

  @override
  State<HoldToPeelRing> createState() => _HoldToPeelRingState();
}

class _HoldToPeelRingState extends State<HoldToPeelRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  );
  bool _committed = false;
  int _lastHapticStep = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTick);
    _ctrl.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!widget.enabled) return;
    // Fire a light haptic every ~20% of progress — signals the anti-
    // cheat engine that contact is sustained and gives sensory rhythm.
    final step = (_ctrl.value * 5).floor();
    if (step != _lastHapticStep) {
      _lastHapticStep = step;
      if (widget.haptics && step > 0 && step < 5) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_committed && widget.enabled) {
      _committed = true;
      if (widget.haptics) HapticFeedback.heavyImpact();
      widget.onCommit();
    }
  }

  void _startHold() {
    if (!widget.enabled || _committed) return;
    _ctrl.duration = widget.holdDuration;
    _ctrl.forward();
  }

  void _cancelHold() {
    if (_committed) return;
    _ctrl.duration = widget.releaseDuration;
    _ctrl.reverse();
    _lastHapticStep = 0;
  }

  @override
  Widget build(BuildContext context) {
    // Reduced-motion: drop the hold-ring interaction to a single button
    // activation. Anti-cheat still enforced server-side; this just keeps
    // the UX accessible to motor-impaired / reduced-motion users.
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      return Semantics(
        button: true,
        label: 'Peel the package',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!widget.enabled || _committed) return;
            _committed = true;
            if (widget.haptics) HapticFeedback.heavyImpact();
            widget.onCommit();
          },
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(child: widget.child),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Press and hold to peel the package',
      hint: 'Hold for 1.4 seconds. Releasing early cancels.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _startHold(),
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        onLongPressStart: (_) => _startHold(),
        onLongPressEnd: (_) => _cancelHold(),
        onLongPressCancel: _cancelHold,
        onPanEnd: (_) => _cancelHold(),
        onPanCancel: _cancelHold,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return CustomPaint(
                painter: _RingPainter(
                  progress: _ctrl.value,
                  accent: widget.accent,
                  enabled: widget.enabled,
                ),
                child: Center(child: widget.child),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.accent,
    required this.enabled,
  });

  final double progress;
  final Color accent;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 10;

    // Track — full ring, dim.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(enabled ? 0.10 : 0.04),
    );

    // Progress arc.
    final sweep = progress * 2 * pi;
    if (sweep > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: -pi / 2,
            endAngle: -pi / 2 + max(sweep, 0.1),
            colors: [accent.withOpacity(0.2), accent],
          ).createShader(
            Rect.fromCircle(center: center, radius: r),
          ),
      );
    }

    // Glow on the leading tip.
    if (progress > 0) {
      final tipAngle = -pi / 2 + sweep;
      final tip = center + Offset(cos(tipAngle), sin(tipAngle)) * r;
      canvas.drawCircle(
        tip,
        9,
        Paint()
          ..color = accent.withOpacity(0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Soft inner halo — appears only while holding.
    if (progress > 0) {
      canvas.drawCircle(
        center,
        r * 0.98,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accent.withOpacity(0.14 * progress),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: r * 0.98),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.accent != accent || old.enabled != enabled;
}
