import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Lightweight confetti overlay — fires once per [fireKey] change.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    required this.fireKey,
    this.rarity = 'mythic',
    this.particleCount = 80,
  });

  final Object fireKey;
  final String rarity;
  final int particleCount;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  final _rng = math.Random();
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    _particles = _gen();
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant ConfettiOverlay old) {
    super.didUpdateWidget(old);
    if (old.fireKey != widget.fireKey) {
      _particles = _gen();
      _c
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<_Particle> _gen() {
    final palette = AppColors.forRarity(widget.rarity);
    return List.generate(widget.particleCount, (_) {
      final ang = _rng.nextDouble() * math.pi * 2;
      final speed = 300 + _rng.nextDouble() * 500;
      return _Particle(
        angle: ang,
        speed: speed,
        color: [palette.fill, palette.stroke, Colors.white, AppColors.gold]
            .elementAt(_rng.nextInt(4)),
        size: 4 + _rng.nextDouble() * 6,
        spin: (_rng.nextDouble() - 0.5) * 10,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return CustomPaint(
            painter: _ConfettiPainter(
              particles: _particles,
              t: _c.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.spin,
  });
  final double angle;
  final double speed;
  final Color color;
  final double size;
  final double spin;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.t});
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (final p in particles) {
      final dx = math.cos(p.angle) * p.speed * t;
      final dy = math.sin(p.angle) * p.speed * t + 0.5 * 1400 * t * t;
      final opacity = (1 - t).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withOpacity(opacity);
      canvas.save();
      canvas.translate(center.dx + dx, center.dy + dy);
      canvas.rotate(p.spin * t);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
