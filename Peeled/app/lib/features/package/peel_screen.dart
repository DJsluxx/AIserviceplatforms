import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/providers.dart';
import '../../shared/widgets/coin_balance.dart';
import '../../shared/widgets/juicy_button.dart';
import '../../shared/widgets/live_countdown.dart';

class PeelScreen extends ConsumerStatefulWidget {
  const PeelScreen({super.key, required this.packageId});

  /// Path param kept for API parity, not strictly needed — there is
  /// exactly one live package at a time.
  final String packageId;

  @override
  ConsumerState<PeelScreen> createState() => _PeelScreenState();
}

class _PeelScreenState extends ConsumerState<PeelScreen>
    with TickerProviderStateMixin {
  int _revealKey = 0;
  int _lastSeenLayers = 0;
  int _lastSeenCoins = 0;
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(gameStateProvider).state;
    _lastSeenLayers = s.package.layersRevealed;
    _lastSeenCoins = s.user.coins;
  }

  @override
  Widget build(BuildContext context) {
    final sim = ref.watch(gameStateProvider);
    final s = sim.state;
    final hop = s.package.currentHop;

    // Detect a layer reveal transition so we can show the hint sheet.
    if (s.package.layersRevealed > _lastSeenLayers) {
      final coinsGained = s.user.coins - _lastSeenCoins;
      _lastSeenLayers = s.package.layersRevealed;
      _revealKey++;
      final lastHint = s.package.hints.isNotEmpty ? s.package.hints.last : '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLayerRevealed(context, lastHint, coinsGained: coinsGained);
        _lastSeenCoins = s.user.coins;
      });
    }

    // Opened!
    if (s.package.opened && !_celebrated) {
      _celebrated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showOpenedSheet(context, sim.newRewardHeadline());
      });
    }

    final isMine = hop.holderId == s.user.id && !s.package.opened;

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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: CoinBalance(coins: s.user.coins),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined,
                      color: AppColors.textMuted, size: 18),
                  const SizedBox(width: 6),
                  LiveCountdown(
                    remaining: hop.remaining(s.now),
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isMine
                    ? 'Tap the package to peel'
                    : 'Watching: ${s.currentHolder.name}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: _PeelTarget(
                  enabled: isMine,
                  progress: hop.peelProgress,
                  peelsDone: hop.peelsDone,
                  peelsRequired: hop.peelsRequired,
                  revealKey: _revealKey,
                  onTap: () {
                    if (!isMine) return;
                    sim.peelTap();
                    if (s.hapticsEnabled) HapticFeedback.lightImpact();
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _LayersIndicator(revealed: s.package.layersRevealed),
              const SizedBox(height: AppSpacing.md),
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: JuicyButton(
                    label: 'Back to live feed',
                    icon: Icons.radar_outlined,
                    primary: AppColors.violet,
                    onPressed: () => context.go('/home'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLayerRevealed(BuildContext context, String hint,
      {required int coinsGained}) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: AppColors.surfaceDarkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '✨ LAYER REVEALED',
              style: TextStyle(
                color: AppColors.mint,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textOnDark,
                fontFamily: 'Fraunces',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            if (coinsGained > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                '+$coinsGained 🪙',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            JuicyButton(
              label: 'Keep peeling',
              primary: AppColors.coral,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _showOpenedSheet(BuildContext context, String headline) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surfaceDarkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textOnDark,
                fontFamily: 'Fraunces',
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'A new package is already on its way.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            JuicyButton(
              label: 'Back to live feed',
              primary: AppColors.coral,
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/home');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PeelTarget extends StatefulWidget {
  const _PeelTarget({
    required this.enabled,
    required this.progress,
    required this.peelsDone,
    required this.peelsRequired,
    required this.revealKey,
    required this.onTap,
  });

  final bool enabled;
  final double progress;
  final int peelsDone;
  final int peelsRequired;
  final int revealKey;
  final VoidCallback onTap;

  @override
  State<_PeelTarget> createState() => _PeelTargetState();
}

class _PeelTargetState extends State<_PeelTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    duration: const Duration(milliseconds: 180),
    vsync: this,
  );
  int _floatingId = 0;
  final List<_Float> _floats = [];
  final _rng = Random();

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _tap() {
    _pop
      ..reset()
      ..forward();
    final id = _floatingId++;
    setState(() {
      _floats.add(_Float(id: id, dx: (_rng.nextDouble() - 0.5) * 120));
    });
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _floats.removeWhere((f) => f.id == id));
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final side = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
        final size = side * 0.82;
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: side,
                height: side,
                child: CustomPaint(
                  painter: _ProgressRingPainter(
                    progress: widget.progress,
                    color: AppColors.coral,
                    backgroundColor: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.enabled ? _tap : null,
                child: AnimatedBuilder(
                  animation: _pop,
                  builder: (_, __) {
                    final scale = 1 - 0.06 * _pop.value;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: widget.enabled
                                ? const [AppColors.kraft, AppColors.kraftDeep]
                                : [
                                    AppColors.kraft.withOpacity(0.55),
                                    AppColors.kraftDeep.withOpacity(0.55)
                                  ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x88000000),
                                blurRadius: 24,
                                offset: Offset(0, 12)),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '📦',
                            style: TextStyle(fontSize: size * 0.42),
                          )
                              .animate(key: ValueKey(widget.revealKey))
                              .shake(hz: 8, duration: 400.ms),
                        ),
                      ),
                    );
                  },
                ),
              ),
              for (final f in _floats)
                _FloatingPeel(key: ValueKey(f.id), dx: f.dx),
              Positioned(
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${_compact(widget.peelsDone)} / ${_compact(widget.peelsRequired)}',
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });
  final double progress;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = backgroundColor;
    canvas.drawCircle(center, radius, bgPaint);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress || old.color != color;
}

class _Float {
  _Float({required this.id, required this.dx});
  final int id;
  final double dx;
}

class _FloatingPeel extends StatefulWidget {
  const _FloatingPeel({super.key, required this.dx});
  final double dx;

  @override
  State<_FloatingPeel> createState() => _FloatingPeelState();
}

class _FloatingPeelState extends State<_FloatingPeel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 700),
    vsync: this,
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Transform.translate(
          offset: Offset(widget.dx * t, -120 * t),
          child: Opacity(
            opacity: 1 - t,
            child: const Text(
              '+1',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LayersIndicator extends StatelessWidget {
  const _LayersIndicator({required this.revealed});
  final int revealed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(8, (i) {
        final on = i < revealed;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? AppColors.mint : Colors.white.withOpacity(0.1),
              border: Border.all(
                color: on ? AppColors.mint : Colors.white.withOpacity(0.15),
              ),
            ),
          ),
        );
      }),
    );
  }
}

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return n.toString();
}
