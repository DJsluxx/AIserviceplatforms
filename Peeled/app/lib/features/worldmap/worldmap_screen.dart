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
import '../../shared/widgets/themed_package.dart';

/// Full-screen globe of one selected package. A chip row at the top
/// lets you switch between the packages currently available in your
/// region (global + any regional drops). The selected package's
/// current city, the previous city, and a curved arrow between them
/// are drawn big on an equirectangular canvas.
class WorldmapScreen extends ConsumerStatefulWidget {
  const WorldmapScreen({super.key});

  @override
  ConsumerState<WorldmapScreen> createState() => _WorldmapScreenState();
}

class _WorldmapScreenState extends ConsumerState<WorldmapScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final sim = ref.watch(gameStateProvider);
    final s = sim.state;
    final visible = s.visiblePackagesFor(s.user.regionCode);
    if (visible.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.surfaceDark,
        body: Center(
          child: Text('No live packages in your region',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    // Default to the first (global) one; stick to the user's choice
    // across rebuilds.
    _selectedId ??= visible.first.id;
    final pkg = visible.firstWhere(
      (p) => p.id == _selectedId,
      orElse: () => visible.first,
    );

    final holder = s.holderOf(pkg);
    final previous = s.previousHolderOf(pkg);
    final hop = pkg.currentHop;
    final palette = paletteForPackage(pkg.theme, pkg.rarity);

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
            if (visible.length > 1)
              _PackageChips(
                packages: visible,
                selectedId: pkg.id,
                onChanged: (id) => setState(() => _selectedId = id),
              ),
            if (visible.length > 1) const SizedBox(height: AppSpacing.sm),
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
                      CustomPaint(
                        painter: _GridPainter(),
                        size: Size(c.maxWidth, c.maxHeight),
                      ),
                      if (previous != null)
                        CustomPaint(
                          painter: _TrailPainter(
                            from: _project(
                                previous.lat, previous.lon, c.maxWidth, c.maxHeight),
                            to: _project(
                                holder.lat, holder.lon, c.maxWidth, c.maxHeight),
                            color: palette.fill,
                          ),
                          size: Size(c.maxWidth, c.maxHeight),
                        ),
                      if (previous != null)
                        _CityDot(
                          left: _project(previous.lat, previous.lon,
                                  c.maxWidth, c.maxHeight)
                              .dx,
                          top: _project(previous.lat, previous.lon,
                                  c.maxWidth, c.maxHeight)
                              .dy,
                          label: '${previous.city} ${previous.flag}',
                          active: false,
                          color: palette.fill,
                        ),
                      _CityDot(
                        left: _project(holder.lat, holder.lon, c.maxWidth,
                                c.maxHeight)
                            .dx,
                        top: _project(holder.lat, holder.lon, c.maxWidth,
                                c.maxHeight)
                            .dy,
                        label: '${holder.city} ${holder.flag}',
                        active: true,
                        color: palette.fill,
                      ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _HopCard(
              package: pkg,
              holder: holder,
              previous: previous,
              remaining: hop.remaining(s.now),
            ),
            const SizedBox(height: AppSpacing.sm),
            _RecentCities(package: pkg, state: s),
          ],
        ),
      ),
    );
  }

  Offset _project(double lat, double lon, double w, double h) {
    final x = (lon + 180.0) / 360.0 * w;
    final y = ((90.0 - lat) / 180.0).clamp(0.0, 1.0) * h;
    return Offset(x, y);
  }
}

class _PackageChips extends StatelessWidget {
  const _PackageChips({
    required this.packages,
    required this.selectedId,
    required this.onChanged,
  });
  final List<Package> packages;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: packages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = packages[i];
          final selected = p.id == selectedId;
          final palette = paletteForPackage(p.theme, p.rarity);
          return GestureDetector(
            onTap: () => onChanged(p.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? palette.fill.withOpacity(0.2)
                    : AppColors.surfaceDarkElevated,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: selected
                        ? palette.fill
                        : Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.regionEmoji,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    p.regionLabel,
                    style: TextStyle(
                      color: selected ? palette.fill : AppColors.textOnDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CityDot extends StatelessWidget {
  const _CityDot({
    required this.left,
    required this.top,
    required this.label,
    required this.active,
    required this.color,
  });
  final double left;
  final double top;
  final String label;
  final bool active;
  final Color color;

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
            color: active ? color : AppColors.textMuted.withOpacity(0.5),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.6),
                        blurRadius: 28,
                        spreadRadius: 6)
                  ]
                : null,
          ),
          child: active
              ? Text('📦', style: TextStyle(fontSize: size * 0.5))
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
              border: Border.all(color: color.withOpacity(0.5)),
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
  _TrailPainter({required this.from, required this.to, required this.color});
  final Offset from;
  final Offset to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = Offset(
      (from.dx + to.dx) / 2,
      (from.dy + to.dy) / 2 - 60,
    );
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glow);

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color;
    const dashLen = 8.0;
    const gapLen = 6.0;
    final metric = path.computeMetrics().first;
    double t = 0;
    while (t < metric.length) {
      final extract =
          metric.extractPath(t, (t + dashLen).clamp(0, metric.length));
      canvas.drawPath(extract, dash);
      t += dashLen + gapLen;
    }

    final tangent = metric.getTangentForOffset(metric.length)!;
    final arrowAngle = tangent.angle;
    const arrowLen = 12.0;
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
    canvas.drawPath(tri, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.from != from || old.to != to || old.color != color;
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
    required this.package,
    required this.holder,
    required this.previous,
    required this.remaining,
  });
  final Package package;
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
          Text(package.regionEmoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${package.name} in ${holder.city} ${holder.flag}',
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
  const _RecentCities({required this.package, required this.state});
  final Package package;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final hops = package.hops;
    final previous = hops.length > 1
        ? hops.sublist(0, hops.length - 1).reversed.take(5).toList()
        : <PackageHop>[];
    if (previous.isEmpty) return const SizedBox.shrink();
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
            child: Text(
              '$city $flag',
              style: const TextStyle(
                color: AppColors.textOnDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
    );
  }
}
