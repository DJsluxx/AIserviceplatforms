import 'dart:math';

import 'package:flutter/material.dart';

/// Slow-drifting dust specks that float upward inside the beam of light.
///
/// Uses a single [AnimationController] as a time source and a fixed pool
/// of 18 motes (seeded deterministically so the pattern is stable across
/// frames without needing a random call per tick).
class DustMotes extends StatefulWidget {
  const DustMotes({
    super.key,
    required this.accent,
    this.motes = 18,
  });

  final Color accent;
  final int motes;

  @override
  State<DustMotes> createState() => _DustMotesState();
}

class _DustMotesState extends State<DustMotes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  late final List<_Mote> _pool = _seed(widget.motes);

  List<_Mote> _seed(int n) {
    final rng = Random(17);
    return List.generate(n, (_) {
      return _Mote(
        xSeed: rng.nextDouble(),
        speed: 0.35 + rng.nextDouble() * 0.75,
        phase: rng.nextDouble(),
        radius: 0.6 + rng.nextDouble() * 1.5,
        sway: (rng.nextDouble() - 0.5) * 2,
      );
    });
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the OS "reduce motion" setting: draw a single still frame
    // of dust instead of running the ticker.
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      return IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _DustPainter(
              pool: _pool,
              time: 0.0,
              accent: widget.accent,
            ),
            size: Size.infinite,
          ),
        ),
      );
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _t,
          builder: (_, __) {
            return CustomPaint(
              painter: _DustPainter(
                pool: _pool,
                time: _t.value,
                accent: widget.accent,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _Mote {
  const _Mote({
    required this.xSeed,
    required this.speed,
    required this.phase,
    required this.radius,
    required this.sway,
  });
  final double xSeed;
  final double speed;
  final double phase;
  final double radius;
  final double sway;
}

class _DustPainter extends CustomPainter {
  _DustPainter({
    required this.pool,
    required this.time,
    required this.accent,
  });

  final List<_Mote> pool;
  final double time; // 0..1 loop
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final paint = Paint();
    for (final m in pool) {
      // progress is a looping value in [0,1] staggered per mote.
      final progress = ((time * m.speed) + m.phase) % 1.0;
      // Motes travel bottom → top, fading in/out at the ends.
      final y = h * (1 - progress);
      // Cone widens from ~14% (top) to ~62% (bottom). Lerp using y.
      final coneHalfWidth = _lerp(w * 0.07, w * 0.31, 1 - progress);
      final sway =
          sin((time * 2 * pi) + m.xSeed * 6 + m.phase * 4) * m.sway * 10;
      final x = cx + (m.xSeed - 0.5) * coneHalfWidth * 2 + sway;

      // Opacity ramps in from 0 at bottom, peaks mid, fades to 0 at top.
      final a = (progress < 0.5 ? progress * 2 : (1 - progress) * 2);
      paint.color = accent.withOpacity(0.15 + a * 0.45);
      canvas.drawCircle(Offset(x, y), m.radius, paint);

      // Tiny bloom — draw a larger faint halo.
      paint.color = accent.withOpacity(0.06 + a * 0.14);
      canvas.drawCircle(Offset(x, y), m.radius * 3, paint);
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _DustPainter old) =>
      old.time != time || old.accent != accent;
}
