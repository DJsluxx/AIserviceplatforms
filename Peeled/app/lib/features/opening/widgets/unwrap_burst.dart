import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// One-shot "layer reveal" animation. Fires a flash of light and a radial
/// spray of colored shards out from the package centre, plus a short
/// shockwave ring. Lives 900 ms.
class UnwrapBurst extends StatefulWidget {
  const UnwrapBurst({
    super.key,
    required this.accent,
    this.shards = 22,
    this.onEnd,
  });

  final Color accent;
  final int shards;
  final VoidCallback? onEnd;

  @override
  State<UnwrapBurst> createState() => _UnwrapBurstState();
}

class _UnwrapBurstState extends State<UnwrapBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  final _rng = Random();
  late final List<_Shard> _pool;

  @override
  void initState() {
    super.initState();
    _pool = List.generate(widget.shards, (_) {
      return _Shard(
        angle: _rng.nextDouble() * 2 * pi,
        distance: 110 + _rng.nextDouble() * 120,
        size: 4 + _rng.nextDouble() * 7,
        color: [
          AppColors.coral,
          AppColors.gold,
          AppColors.mint,
          AppColors.violet,
          widget.accent,
        ][_rng.nextInt(5)],
        spin: (_rng.nextDouble() - 0.5) * 4,
      );
    });
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onEnd?.call();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _UnwrapPainter(
              progress: _c.value,
              accent: widget.accent,
              pool: _pool,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _Shard {
  const _Shard({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.spin,
  });
  final double angle;
  final double distance;
  final double size;
  final Color color;
  final double spin;
}

class _UnwrapPainter extends CustomPainter {
  _UnwrapPainter({
    required this.progress,
    required this.accent,
    required this.pool,
  });

  final double progress;
  final Color accent;
  final List<_Shard> pool;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    // Flash — a bright radial burst that peaks at ~12 % and fades.
    final flashT = progress < 0.12
        ? progress / 0.12
        : 1 - ((progress - 0.12) / 0.38).clamp(0.0, 1.0);
    if (flashT > 0) {
      canvas.drawCircle(
        center,
        180 * (0.6 + flashT * 0.6),
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withOpacity(0.85 * flashT),
              accent.withOpacity(0.35 * flashT),
              Colors.transparent,
            ],
            stops: const [0, 0.35, 1],
          ).createShader(
            Rect.fromCircle(
              center: center,
              radius: 180 * (0.6 + flashT * 0.6),
            ),
          ),
      );
    }

    // Shockwave ring — expands outward, fades.
    final ringT = progress;
    canvas.drawCircle(
      center,
      40 + 210 * ringT,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = accent.withOpacity((1 - ringT) * 0.7),
    );

    // Shards — travel outward and fade.
    for (final s in pool) {
      final d = s.distance * Curves.easeOutCubic.transform(progress);
      final pos = center + Offset(cos(s.angle), sin(s.angle)) * d;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final rotation = s.spin * progress * pi;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: s.size,
            height: s.size * 1.6,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = s.color.withOpacity(alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _UnwrapPainter old) =>
      old.progress != progress || old.accent != accent;
}
