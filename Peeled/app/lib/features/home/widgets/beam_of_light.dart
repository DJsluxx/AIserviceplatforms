import 'package:flutter/material.dart';

/// Downward cone of light that projects onto the pedestal. Rarity-colored.
///
/// Rendered in two layers: a wide soft outer cone and a narrow bright
/// inner cone, both with a top-to-bottom gradient so the beam fades
/// before reaching the bottom of the stage.
class BeamOfLight extends StatelessWidget {
  const BeamOfLight({
    super.key,
    required this.accent,
    this.topWidth = 56,
    this.bottomWidth = 280,
  });

  /// Rarity-aligned color of the beam.
  final Color accent;
  final double topWidth;
  final double bottomWidth;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BeamPainter(
          accent: accent,
          topWidth: topWidth,
          bottomWidth: bottomWidth,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  _BeamPainter({
    required this.accent,
    required this.topWidth,
    required this.bottomWidth,
  });

  final Color accent;
  final double topWidth;
  final double bottomWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Hot spot at the emitter — bright ellipse at the top of the beam.
    final emitterCenter = Offset(cx, 0);
    canvas.drawCircle(
      emitterCenter,
      topWidth * 1.4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withOpacity(0.9),
            accent.withOpacity(0.0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: emitterCenter,
            radius: topWidth * 1.4,
          ),
        ),
      );

    // Outer soft cone.
    final outer = Path()
      ..moveTo(cx - topWidth * 0.9, 0)
      ..lineTo(cx + topWidth * 0.9, 0)
      ..lineTo(cx + bottomWidth * 0.9, h)
      ..lineTo(cx - bottomWidth * 0.9, h)
      ..close();
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withOpacity(0.28),
            accent.withOpacity(0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Inner bright cone.
    final inner = Path()
      ..moveTo(cx - topWidth / 2, 0)
      ..lineTo(cx + topWidth / 2, 0)
      ..lineTo(cx + bottomWidth / 2, h)
      ..lineTo(cx - bottomWidth / 2, h)
      ..close();
    canvas.drawPath(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withOpacity(0.55),
            accent.withOpacity(0.18),
            Colors.transparent,
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Bright vertical core line — a subtle shimmer down the middle.
    final coreRect = Rect.fromLTWH(cx - 1.2, 0, 2.4, h * 0.82);
    canvas.drawRect(
      coreRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.7),
            accent.withOpacity(0.25),
            Colors.transparent,
          ],
          stops: const [0, 0.5, 1],
        ).createShader(coreRect),
    );
  }

  @override
  bool shouldRepaint(covariant _BeamPainter old) =>
      old.accent != accent ||
      old.topWidth != topWidth ||
      old.bottomWidth != bottomWidth;
}
