import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/player.dart';
import '../../data/providers.dart';
import '../../data/services/game_simulator.dart';
import '../../shared/widgets/coin_balance.dart';
import '../../shared/widgets/live_countdown.dart';
import '../../shared/widgets/player_avatar.dart';

/// Lightweight "globe" — a rectangular equirectangular projection with a
/// dot per AI player and the active holder pulsing. Not Mapbox, but it
/// ships now, works offline, and tells the same story: the package is
/// somewhere in the world, watch it travel.
class WorldmapScreen extends ConsumerWidget {
  const WorldmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sim = ref.watch(gameStateProvider);
    final s = sim.state;

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
          style: TextStyle(
              fontFamily: 'Fraunces', fontWeight: FontWeight.w700),
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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  gradient: const RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [Color(0xFF1D2A4D), AppColors.surfaceDark],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(builder: (context, c) {
                  return Stack(
                    children: [
                      CustomPaint(
                        painter: _GridPainter(),
                        size: Size(c.maxWidth, c.maxHeight),
                      ),
                      for (final p in AiPlayers.all)
                        _PlayerDot(
                          left: _lonToX(p.lon, c.maxWidth),
                          top: _latToY(p.lat, c.maxHeight),
                          player: p,
                          active:
                              p.id == s.package.currentHop.holderId,
                        ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _HolderSummary(state: s),
          ],
        ),
      ),
    );
  }

  double _lonToX(double lon, double w) => (lon + 180.0) / 360.0 * w;
  double _latToY(double lat, double h) {
    // Equirectangular; clamp at poles.
    final t = (90.0 - lat) / 180.0;
    return t.clamp(0.0, 1.0) * h;
  }
}

class _PlayerDot extends StatelessWidget {
  const _PlayerDot({
    required this.left,
    required this.top,
    required this.player,
    required this.active,
  });
  final double left;
  final double top;
  final Player player;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final size = active ? 56.0 : 28.0;
    final widget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerAvatar(
          emoji: player.avatar,
          size: size,
          ring: active,
          tint: active ? AppColors.coral : null,
        ),
        const SizedBox(height: 2),
        Text(
          player.city,
          style: TextStyle(
            fontSize: active ? 11 : 9,
            fontWeight: FontWeight.w800,
            color:
                active ? AppColors.textOnDark : AppColors.textMuted,
          ),
        ),
      ],
    );
    return Positioned(
      left: left - size / 2,
      top: top - size / 2,
      child: active
          ? widget.animate(onPlay: (c) => c.repeat()).scale(
                begin: const Offset(1, 1),
                end: const Offset(1.06, 1.06),
                duration: 800.ms,
                curve: Curves.easeInOut,
              ).then().scale(
                begin: const Offset(1.06, 1.06),
                end: const Offset(1, 1),
                duration: 800.ms,
                curve: Curves.easeInOut,
              )
          : widget,
    );
  }
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
    // Equator + prime meridian, faintly.
    final eq = Paint()
      ..color = AppColors.coral.withOpacity(0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), eq);
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), eq);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HolderSummary extends StatelessWidget {
  const _HolderSummary({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final holder = state.currentHolder;
    final hop = state.package.currentHop;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDarkElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          PlayerAvatar(emoji: holder.avatar, size: 48),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Now with ${holder.name}',
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${holder.city} ${holder.flag}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          LiveCountdown(
            remaining: hop.remaining(state.now),
            style: const TextStyle(
              color: AppColors.textOnDark,
              fontFamily: 'Fraunces',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

