import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/game_state.dart';
import '../../data/models/player.dart';
import 'themed_package.dart';

/// Compact world-map card embedded inside a package card on Home.
/// Plots the last up-to-5 cities this package has visited, with the
/// current holder as a pulsing filled dot and the trail before it as
/// smaller faded dots. The line connecting them animates as a soft
/// pulse the same colour as the package's theme.
class MiniGlobe extends StatelessWidget {
  const MiniGlobe({
    super.key,
    required this.package,
    required this.holders,
    this.height = 120,
  });

  final Package package;

  /// Ordered oldest-first list of [Player]s for the most recent hops
  /// (max ~5). The last entry is the current holder.
  final List<Player> holders;

  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = paletteForPackage(package.theme, package.rarity);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: const RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Color(0xFF1D2A4D), AppColors.surfaceDark],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, c) {
        final points = [
          for (final p in holders) _project(p.lat, p.lon, c.maxWidth, c.maxHeight)
        ];
        return Stack(
          children: [
            CustomPaint(
              painter: _MiniGridPainter(),
              size: Size(c.maxWidth, c.maxHeight),
            ),
            if (points.length >= 2)
              CustomPaint(
                painter: _TrailPainter(points: points, color: palette.fill),
                size: Size(c.maxWidth, c.maxHeight),
              ),
            for (int i = 0; i < points.length; i++)
              _DotMarker(
                at: points[i],
                active: i == points.length - 1,
                color: palette.fill,
                city: holders[i].city,
                flag: holders[i].flag,
              ),
          ],
        );
      }),
    );
  }

  Offset _project(double lat, double lon, double w, double h) {
    final x = (lon + 180.0) / 360.0 * w;
    final y = ((90.0 - lat) / 180.0).clamp(0.0, 1.0) * h;
    return Offset(x, y);
  }
}

class _DotMarker extends StatefulWidget {
  const _DotMarker({
    required this.at,
    required this.active,
    required this.color,
    required this.city,
    required this.flag,
  });
  final Offset at;
  final bool active;
  final Color color;
  final String city;
  final String flag;

  @override
  State<_DotMarker> createState() => _DotMarkerState();
}

class _DotMarkerState extends State<_DotMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 1200),
    vsync: this,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseSize = widget.active ? 14.0 : 7.0;
    return Positioned(
      left: widget.at.dx - baseSize / 2,
      top: widget.at.dy - baseSize / 2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = widget.active ? _c.value : 0.0;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (widget.active)
                Container(
                  width: baseSize * (2.2 + 1.2 * t),
                  height: baseSize * (2.2 + 1.2 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withOpacity(0.18 * (1 - t)),
                  ),
                ),
              Container(
                width: baseSize,
                height: baseSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.active
                      ? widget.color
                      : widget.color.withOpacity(0.55),
                  boxShadow: widget.active
                      ? [
                          BoxShadow(
                            color: widget.color.withOpacity(0.8),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              if (widget.active)
                Positioned(
                  top: baseSize + 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.ink.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${widget.city} ${widget.flag}',
                      style: const TextStyle(
                        color: AppColors.textOnDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.points, required this.color});
  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    // Sequential dashed lines between each pair, fading with age.
    for (int i = 0; i < points.length - 1; i++) {
      final fade = (i + 1) / (points.length - 1);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withOpacity(0.25 + 0.55 * fade);
      _drawDashedLine(canvas, points[i], points[i + 1], paint, 4, 3);
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint,
    double dash,
    double gap,
  ) {
    final d = b - a;
    final total = d.distance;
    if (total == 0) return;
    final dir = d / total;
    double t = 0;
    while (t < total) {
      final p0 = a + dir * t;
      final end = (t + dash).clamp(0, total).toDouble();
      final p1 = a + dir * end;
      canvas.drawLine(p0, p1, paint);
      t += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.points != points || old.color != color;
}

class _MiniGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    for (int i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Subtle equator hint.
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()..color = Colors.white.withOpacity(0.04),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
