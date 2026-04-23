import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Stylised globe + starfield + vignette gradient that sits behind the
/// sanctuary stage. Static painter — painted once per colour/size change.
class SanctuaryBackground extends StatelessWidget {
  const SanctuaryBackground({super.key, required this.accent});

  /// Rarity accent colour used for the globe arcs + halo.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SanctuaryBackgroundPainter(accent: accent),
        size: Size.infinite,
      ),
    );
  }
}

class _SanctuaryBackgroundPainter extends CustomPainter {
  _SanctuaryBackgroundPainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base vertical gradient — deep space on top fading to brand navy.
    final baseRect = Offset.zero & size;
    canvas.drawRect(
      baseRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF050611),
            Color(0xFF0A0B1D),
            AppColors.surfaceDark,
          ],
          stops: [0, 0.5, 1],
        ).createShader(baseRect),
    );

    // Subtle radial halo behind where the hero package will sit.
    final heroCenter = Offset(w / 2, h * 0.40);
    final haloRect =
        Rect.fromCircle(center: heroCenter, radius: w * 0.9);
    canvas.drawRect(
      baseRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withOpacity(0.22),
            accent.withOpacity(0.06),
            Colors.transparent,
          ],
          stops: const [0, 0.35, 1],
        ).createShader(haloRect),
    );

    // Deterministic starfield — seed makes it stable across rebuilds.
    final rng = Random(8091);
    final starPaint = Paint()..color = Colors.white.withOpacity(0.55);
    for (int i = 0; i < 90; i++) {
      final x = rng.nextDouble() * w;
      final y = rng.nextDouble() * h * 0.6;
      final r = rng.nextDouble() * 1.3 + 0.2;
      starPaint.color = Colors.white.withOpacity(0.15 + rng.nextDouble() * 0.45);
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }

    // Stylised globe — concentric ellipse arcs behind the hero. Not a
    // literal world map, more of a "planet at night" silhouette.
    final globeCenter = Offset(w / 2, h * 0.46);
    final globeR = w * 0.42;
    final globeRect =
        Rect.fromCircle(center: globeCenter, radius: globeR);

    // Globe body — dark, barely visible.
    canvas.drawCircle(
      globeCenter,
      globeR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withOpacity(0.08),
            const Color(0xFF0D0E22).withOpacity(0.7),
          ],
        ).createShader(globeRect),
    );

    // Latitude arcs.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = accent.withOpacity(0.45);
    for (int i = 1; i <= 5; i++) {
      final t = i / 6;
      final r = globeR * t;
      final rect = Rect.fromCenter(
        center: globeCenter,
        width: globeR * 2,
        height: r * 2,
      );
      canvas.drawArc(rect, pi, pi, false, arc);
    }

    // Longitude-style vertical arcs, a little fainter.
    arc.color = accent.withOpacity(0.25);
    for (int i = -2; i <= 2; i++) {
      final rect = Rect.fromCenter(
        center: globeCenter,
        width: globeR * 2 * (1 - i.abs() * 0.22),
        height: globeR * 2,
      );
      canvas.drawArc(rect, 0.15 + pi, pi - 0.3, false, arc);
    }

    // Globe outline ring.
    canvas.drawCircle(
      globeCenter,
      globeR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withOpacity(0.55),
    );

    // Wide soft glow directly below where the pedestal will sit —
    // ties the background to the foreground without a hard line.
    canvas.drawCircle(
      Offset(w / 2, h * 0.72),
      w * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withOpacity(0.12),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(w / 2, h * 0.72), radius: w * 0.55),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _SanctuaryBackgroundPainter old) =>
      old.accent != accent;
}
