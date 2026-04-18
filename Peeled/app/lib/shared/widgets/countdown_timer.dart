import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Radial countdown — starts green, fades through gold, pulses red in the
/// final 5 seconds. Used on the peel screen as the sacred timer.
class CountdownTimer extends StatefulWidget {
  const CountdownTimer({
    super.key,
    required this.total,
    required this.deadline,
    this.size = 96,
    this.onExpire,
  });

  final Duration total;
  final DateTime deadline;
  final double size;
  final VoidCallback? onExpire;

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _tick;
  bool _firedExpire = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {});
      final remaining = widget.deadline.difference(DateTime.now());
      if (remaining.isNegative && !_firedExpire) {
        _firedExpire = true;
        widget.onExpire?.call();
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.deadline.difference(DateTime.now());
    final totalMs = widget.total.inMilliseconds.toDouble();
    final remMs = remaining.inMilliseconds.clamp(0, totalMs.toInt()).toDouble();
    final progress = totalMs <= 0 ? 0.0 : remMs / totalMs;

    Color ring;
    if (progress > 0.5) {
      ring = AppColors.success;
    } else if (progress > 0.15) {
      ring = AppColors.gold;
    } else {
      ring = AppColors.danger;
    }

    final pulse = progress <= 0.15
        ? 0.5 + 0.5 * math.sin(DateTime.now().millisecondsSinceEpoch / 80.0)
        : 1.0;

    final secsText = math.max(0, (remMs / 1000).ceil()).toString();

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          CustomPaint(
            painter: _RingPainter(progress: progress, color: ring, pulse: pulse),
          ),
          Center(
            child: Text(
              secsText,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: widget.size * 0.38,
                fontWeight: FontWeight.w800,
                color: ring,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.pulse});
  final double progress;
  final Color color;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;
    final track = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = color.withOpacity(0.85 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color || old.pulse != pulse;
}
