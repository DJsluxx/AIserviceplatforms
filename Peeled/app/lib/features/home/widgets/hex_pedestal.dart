import 'dart:math';

import 'package:flutter/material.dart';

/// Hexagonal platform under the floating package. Rarity-tinted glow +
/// faint grid lines + subtle concentric pulse rings. Static except the
/// [pulse] value which drives the outer ring scale.
class HexPedestal extends StatelessWidget {
  const HexPedestal({
    super.key,
    required this.accent,
    required this.pulse,
  });

  /// Rarity accent colour.
  final Color accent;

  /// 0..1 animation value driving the outer pulse rings.
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _HexPedestalPainter(accent: accent, pulse: pulse),
        size: Size.infinite,
      ),
    );
  }
}

class _HexPedestalPainter extends CustomPainter {
  _HexPedestalPainter({required this.accent, required this.pulse});

  final Color accent;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h * 0.55);
    final r = w * 0.42;

    // Outer pulse rings — two expanding, fading circles.
    for (int i = 0; i < 2; i++) {
      final t = (pulse + i * 0.5) % 1.0;
      final rr = r * (1.0 + t * 0.45);
      canvas.drawCircle(
        center,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = accent.withOpacity((1 - t) * 0.35),
      );
    }

    // Soft glow pad under the hexagon.
    canvas.drawCircle(
      center,
      r * 1.15,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withOpacity(0.4),
            accent.withOpacity(0.05),
            Colors.transparent,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(
          Rect.fromCircle(center: center, radius: r * 1.15),
        ),
    );

    // Hexagon body.
    final hex = _hexPath(center, r);
    canvas.drawPath(
      hex,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withOpacity(0.55),
            accent.withOpacity(0.18),
          ],
        ).createShader(
          Rect.fromCircle(center: center, radius: r),
        ),
    );

    // Hexagon stroke.
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withOpacity(0.85),
    );

    // Inner hex grid — smaller hex + spokes.
    final innerR = r * 0.58;
    canvas.drawPath(
      _hexPath(center, innerR),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withOpacity(0.18),
    );
    for (int i = 0; i < 6; i++) {
      final a = -pi / 2 + i * (pi / 3);
      canvas.drawLine(
        center,
        center + Offset(cos(a), sin(a)) * r,
        Paint()
          ..strokeWidth = 0.8
          ..color = Colors.white.withOpacity(0.10),
      );
    }

    // Highlight rim along top-left edge — simulates the beam hitting it.
    final rimPath = Path();
    final rimStart = -pi / 2 - pi / 3;
    final rimEnd = -pi / 2 + pi / 6;
    for (int i = 0; i < 24; i++) {
      final t = i / 23;
      final a = rimStart + (rimEnd - rimStart) * t;
      final p = center + Offset(cos(a), sin(a)) * r;
      if (i == 0) {
        rimPath.moveTo(p.dx, p.dy);
      } else {
        rimPath.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      rimPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withOpacity(0.55),
    );
  }

  Path _hexPath(Offset center, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = -pi / 2 + i * (pi / 3);
      final p = center + Offset(cos(a), sin(a) * 0.55) * r; // squashed
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexPedestalPainter old) =>
      old.accent != accent || old.pulse != pulse;
}
