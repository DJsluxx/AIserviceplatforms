import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/game_state.dart';
import '../../data/models/player.dart';
import '../../data/providers.dart';
import '../../data/services/game_simulator.dart';
import '../../shared/widgets/coin_balance.dart';
import '../../shared/widgets/live_countdown.dart';

/// Live Globe. The package is the star — a single big pulsing dot at
/// the current holder's city with a curved trail back to where it came
/// from. A chip strip below shows the last ~5 cities it passed through.
/// No other players shown — this screen is about the package.
class WorldmapScreen extends ConsumerWidget {
  const WorldmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sim = ref.watch(gameStateProvider);
    final s = sim.state;
    final holder = s.currentHolder;
    final previous = s.previousHolder;
    final hop = s.package.currentHop;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textOnDark),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text(
          'Live Globe',
          style:
              TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: CoinBalance(coins: s.user.coins),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  gradient: const RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [Color(0xFF1D2A4D), AppColors.surfaceDark],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: LayoutBuilder(builder: (context, c) {
                  return Stack(
                    children: [
                      // Background grid + equator
                      CustomPaint(
                        painter: _GridPainter(),
                        size: Size(c.maxWidth, c.maxHeight),
                      ),
                      // Trail from previous → current holder
                      if (previous != null)
                        CustomPaint(
                          painter: _TrailPainter(
                            from: _project(
                                previous.lat, previous.lon, c.maxWidth, c.maxHeight),
                            to: _project(
                                holder.lat, holder.lon, c.maxWidth, c.maxHeight),
                          ),
                          size: Size(c.maxWidth, c.maxHeight),
                        ),
                      // Previous-holder dot (faded)
                      if (previous != null)
                        _CityDot(
                          left: _project(previous.lat, previous.lon,
                                  c.maxWidth, c.maxHeight)
                              .dx,
                          top: _project(previous.lat, previous.lon,
                                  c.maxWidth, c.maxHeight)
                              .dy,
                          label: '${previous.city} ${previous.flag}',
                          emoji: '•',
                          active: false,
                        ),
                      // Current-holder dot (big, pulsing, with package emoji)
                      _CityDot(
                        left: _project(holder.lat, holder.lon, c.maxWidth,
                                c.maxHeight)
                            .dx,
                        top: _project(holder.lat, holder.lon, c.maxWidth,
                                c.maxHeight)
                            .dy,
                        label: '${holder.city} ${holder.flag}',
                        emoji: '📦',
                        active: true,
                      ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _HopCard(
              holder: holder,
              previous: previous,
              remaining: hop.remaining(s.now),
            ),
            const SizedBox(height: AppSpacing.sm),
            _RecentCities(state: s),
          ],
        ),
      ),
    );
  }

  Offset _project(double lat, double lon, double w, double h) {
    // Equirectangular projection; clamp at poles.
    final x = (lon + 180.0) / 360.0 * w;
    final y = ((90.0 - lat) / 180.0).clamp(0.0, 1.0) * h;
    return Offset(x, y);
  }
}

class _CityDot extends StatelessWidget {
  const _CityDot({
    required this.left,
    required this.top,
    required this.label,
    required this.emoji,
    required this.active,
  });
  final double left;
  final double top;
  final String label;
  final String emoji;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final size = active ? 56.0 : 16.0;
    Widget dot = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AppColors.coral
                : AppColors.textMuted.withOpacity(0.5),
            boxShadow: active
                ? const [
                    BoxShadow(
                        color: Color(0xAAFF6B57),
                        blurRadius: 28,
                        spreadRadius: 6)
                  ]
                : null,
          ),
          child: active
              ? Text(emoji, style: TextStyle(fontSize: size * 0.5))
              : null,
        ),
        if (active) ...[
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.ink.withOpacity(0.85),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.coral.withOpacity(0.5)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textOnDark,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
    if (active) {
      dot = dot.animate(onPlay: (c) => c.repeat(reverse: true)).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.08, 1.08),
            duration: 900.ms,
            curve: Curves.easeInOut,
          );
    }
    return Positioned(
      left: left - size / 2,
      top: top - size / 2,
      child: dot,
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.from, required this.to});
  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = Offset(
      (from.dx + to.dx) / 2,
      (from.dy + to.dy) / 2 - 60, // arc upward
    );
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);

    // Shadow glow.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = AppColors.coral.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glow);

    // Dashed foreground line.
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.coral;
    const dashLen = 8.0;
    const gapLen = 6.0;
    final metric = path.computeMetrics().first;
    double t = 0;
    while (t < metric.length) {
      final extract = metric.extractPath(t, (t + dashLen).clamp(0, metric.length));
      canvas.drawPath(extract, dash);
      t += dashLen + gapLen;
    }

    // Arrowhead at target.
    final tangent = metric.getTangentForOffset(metric.length)!;
    final arrowAngle = tangent.angle;
    final arrowLen = 12.0;
    final p0 = to;
    final p1 = p0 +
        Offset(-cos(arrowAngle + pi / 7), -sin(arrowAngle + pi / 7)) *
            arrowLen;
    final p2 = p0 +
        Offset(-cos(arrowAngle - pi / 7), -sin(arrowAngle - pi / 7)) *
            arrowLen;
    final tri = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(tri, Paint()..color = AppColors.coral);
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.from != from || old.to != to;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    for (int i = 1; i < 12; i++) {
      final x = size.width * i / 12;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int i = 1; i < 8; i++) {
      final y = size.height * i / 8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final eq = Paint()
      ..color = AppColors.coral.withOpacity(0.12)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), eq);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HopCard extends StatelessWidget {
  const _HopCard({
    required this.holder,
    required this.previous,
    required this.remaining,
  });
  final Player holder;
  final Player? previous;
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDarkElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Text('📦', style: TextStyle(fontSize: 40)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The package is in ${holder.city} ${holder.flag}',
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontFamily: 'Fraunces',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  previous == null
                      ? 'Just dropped in — the journey begins.'
                      : 'Came from ${previous!.city} ${previous!.flag}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'WINDOW',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              LiveCountdown(
                remaining: remaining,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentCities extends StatelessWidget {
  const _RecentCities({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    // Last ~5 hops back through time. Skip the current one (user sees
    // it in the hero above).
    final hops = state.package.hops;
    final previous = hops.length > 1
        ? hops.sublist(0, hops.length - 1).reversed.take(5).toList()
        : <PackageHop>[];
    if (previous.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: previous.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final h = previous[i];
          final String city;
          final String flag;
          if (h.holderId == state.user.id) {
            city = state.user.city;
            flag = state.user.flag;
          } else {
            final p = AiPlayers.byId(h.holderId);
            city = p.city;
            flag = p.flag;
          }
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceDarkElevated,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$city $flag',
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
