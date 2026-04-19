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

/// Live Globe — single big map showing every package the player can
/// see in their region as a themed dot at its current city. The player
/// can focus a package via the chip row to see its trail (last hop's
/// arc). The bottom card always shows the focused package's holder,
/// from-city, and 5-minute countdown.
class WorldmapScreen extends ConsumerStatefulWidget {
  const WorldmapScreen({super.key, this.focusPackageId});

  /// Optional `?focus=<id>` deep-link from the package detail screen.
  final String? focusPackageId;

  @override
  ConsumerState<WorldmapScreen> createState() => _WorldmapScreenState();
}

class _WorldmapScreenState extends ConsumerState<WorldmapScreen> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.focusPackageId;
  }

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

    // Default selection: first visible package.
    final selected = visible.firstWhere(
      (p) => p.id == _selectedId,
      orElse: () => visible.first,
    );

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
            _PackageChips(
              packages: visible,
              selectedId: selected.id,
              onChanged: (id) => setState(() => _selectedId = id),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _GlobeCanvas(state: s, packages: visible, selected: selected)),
            const SizedBox(height: AppSpacing.md),
            _SelectedPackageCard(state: s, package: selected),
          ],
        ),
      ),
    );
  }
}

/// The big map. Renders ONE dot per visible package at its current
/// city. The selected package is bigger, glowing, and gets a curved
/// trail back to its previous city.
class _GlobeCanvas extends StatelessWidget {
  const _GlobeCanvas({
    required this.state,
    required this.packages,
    required this.selected,
  });
  final GameState state;
  final List<Package> packages;
  final Package selected;

  Offset _project(double lat, double lon, double w, double h) {
    final x = (lon + 180.0) / 360.0 * w;
    final y = ((90.0 - lat) / 180.0).clamp(0.0, 1.0) * h;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        final selectedHolder = state.holderOf(selected);
        final selectedPrev = state.previousHolderOf(selected);
        final selectedPalette =
            paletteForPackage(selected.theme, selected.rarity);

        return Stack(
          children: [
            CustomPaint(
              painter: _GridPainter(),
              size: Size(c.maxWidth, c.maxHeight),
            ),
            // Trail for the selected package.
            if (selectedPrev != null)
              CustomPaint(
                painter: _TrailPainter(
                  from: _project(selectedPrev.lat, selectedPrev.lon,
                      c.maxWidth, c.maxHeight),
                  to: _project(selectedHolder.lat, selectedHolder.lon,
                      c.maxWidth, c.maxHeight),
                  color: selectedPalette.fill,
                ),
                size: Size(c.maxWidth, c.maxHeight),
              ),
            // Dots for ALL visible packages.
            for (final pkg in packages) ...[
              _PackageDot(
                pkg: pkg,
                holder: state.holderOf(pkg),
                center: _project(state.holderOf(pkg).lat,
                    state.holderOf(pkg).lon, c.maxWidth, c.maxHeight),
                isSelected: pkg.id == selected.id,
                remaining: pkg.currentHop.remaining(state.now),
              ),
            ],
          ],
        );
      }),
    );
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
                      color:
                          selected ? palette.fill : AppColors.textOnDark,
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

/// One coloured dot on the globe representing a single package's
/// current city. The selected package is much larger, has its label
/// hanging beneath, and shows a small countdown chip in its corner.
class _PackageDot extends StatelessWidget {
  const _PackageDot({
    required this.pkg,
    required this.holder,
    required this.center,
    required this.isSelected,
    required this.remaining,
  });

  final Package pkg;
  final Player holder;
  final Offset center;
  final bool isSelected;
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final palette = paletteForPackage(pkg.theme, pkg.rarity);
    final size = isSelected ? 60.0 : 22.0;
    Widget dot = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.fill,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: palette.fill.withOpacity(0.65),
                        blurRadius: 28,
                        spreadRadius: 6),
                  ]
                : [
                    BoxShadow(
                        color: palette.fill.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 1),
                  ],
          ),
          child: Text(
            isSelected ? '📦' : pkg.regionEmoji,
            style: TextStyle(fontSize: size * (isSelected ? 0.5 : 0.6)),
          ),
        ),
        if (isSelected)
          Positioned(
            top: size + 4,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: palette.fill.withOpacity(0.6)),
                  ),
                  child: Text(
                    '${holder.city} ${holder.flag}',
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: palette.fill,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: LiveCountdown(
                    remaining: remaining,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Positioned(
            top: size + 2,
            child: Text(
              holder.city,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
    if (isSelected) {
      dot = dot.animate(onPlay: (c) => c.repeat(reverse: true)).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.08, 1.08),
            duration: 900.ms,
            curve: Curves.easeInOut,
          );
    }
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
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

/// Fixed bottom card showing the selected package's holder, where it
/// came from, and the 5-minute countdown. Tapping it opens the full
/// package detail screen.
class _SelectedPackageCard extends StatelessWidget {
  const _SelectedPackageCard({required this.state, required this.package});
  final GameState state;
  final Package package;

  @override
  Widget build(BuildContext context) {
    final holder = state.holderOf(package);
    final previous = state.previousHolderOf(package);
    final remaining = package.currentHop.remaining(state.now);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => context.push('/package/${package.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceDarkElevated,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Text(package.regionEmoji,
                style: const TextStyle(fontSize: 36)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${package.name} in ${holder.city} ${holder.flag}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontFamily: 'Fraunces',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    previous == null
                        ? 'Just dropped in'
                        : 'from ${previous.city} ${previous.flag}',
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
                const Text(
                  'of 5:00',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
