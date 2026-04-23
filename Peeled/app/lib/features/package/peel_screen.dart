import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/game_state.dart';
import '../../data/providers.dart';
import '../../shared/widgets/coin_balance.dart';
import '../../shared/widgets/juicy_button.dart';
import '../../shared/widgets/live_countdown.dart';
import '../../shared/widgets/themed_package.dart';

/// Single-attempt luck screen for one specific package. The route
/// passes a package id; we pull that package out of game state.
class PeelScreen extends ConsumerStatefulWidget {
  const PeelScreen({super.key, required this.packageId});
  final String packageId;

  @override
  ConsumerState<PeelScreen> createState() => _PeelScreenState();
}

class _PeelScreenState extends ConsumerState<PeelScreen>
    with TickerProviderStateMixin {
  bool _resultShown = false;
  bool _openedShown = false;
  int _coinsAtArrival = 0;

  @override
  void initState() {
    super.initState();
    _coinsAtArrival = ref.read(gameStateProvider).state.user.coins;
  }

  @override
  Widget build(BuildContext context) {
    final sim = ref.watch(gameStateProvider);
    final s = sim.state;
    final pkg = s.packageById(widget.packageId);

    // If the package no longer exists (opened + respawned into a new
    // id), bounce back to Home so the user doesn't get stranded.
    if (pkg == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/home');
      });
      return const Scaffold(
        backgroundColor: AppColors.surfaceDark,
        body: SizedBox.shrink(),
      );
    }

    final hop = pkg.currentHop;
    final isMine = hop.holderId == s.user.id && !pkg.opened;
    final attempted = hop.peelAttempted;

    // Fire the outcome bottom sheet once when the user's attempt
    // resolves on this screen.
    if (attempted && isMine && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (s.hapticsEnabled) {
          if (hop.outcome == PeelOutcome.hit) {
            HapticFeedback.heavyImpact();
          } else {
            HapticFeedback.lightImpact();
          }
        }
        _showResult(
          context,
          hit: hop.outcome == PeelOutcome.hit,
          hint: pkg.hints.isNotEmpty ? pkg.hints.last : '',
          coinsGained: s.user.coins - _coinsAtArrival,
        );
      });
    }

    // Full open celebration if this attempt was the final layer.
    if (pkg.opened && !_openedShown && _resultShown) {
      _openedShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showOpenedSheet(context, sim.newRewardHeadline());
      });
    }

    final palette = paletteForPackage(pkg.theme, pkg.rarity);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pkg.regionEmoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              pkg.name,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
                    ? (attempted
                        ? 'Package is leaving your hands…'
                        : 'Tap the package — one shot')
                    : 'Watching ${s.holderOf(pkg).name}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: _PeelTarget(
                  theme: pkg.theme,
                  rarity: pkg.rarity,
                  palette: palette,
                  enabled: isMine && !attempted,
                  outcome: hop.outcome,
                  onTap: () {
                    if (!isMine || attempted) return;
                    final result = sim.userPeel(pkg.id);
                    if (s.hapticsEnabled) {
                      if (result == PeelOutcome.hit) {
                        HapticFeedback.heavyImpact();
                      } else {
                        HapticFeedback.mediumImpact();
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _LayersIndicator(
                revealed: pkg.layersRevealed,
                total: pkg.layersTotal,
                color: palette.fill,
              ),
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

  void _showResult(
    BuildContext context, {
    required bool hit,
    required String hint,
    required int coinsGained,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: AppColors.surfaceDarkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hit ? '✨ LAYER REVEALED' : '🍃 NO LUCK THIS TIME',
              style: TextStyle(
                color: hit ? AppColors.mint : AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hit ? hint : 'The package slips away untouched.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textOnDark,
                fontFamily: 'Fraunces',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            if (hit && coinsGained > 0) ...[
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
              label: 'Back to live feed',
              primary: hit ? AppColors.coral : AppColors.kraft,
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

  void _showOpenedSheet(BuildContext context, String headline) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surfaceDarkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
    required this.theme,
    required this.rarity,
    required this.palette,
    required this.enabled,
    required this.outcome,
    required this.onTap,
  });

  final PackageTheme theme;
  final PackageRarity rarity;
  final RarityPalette palette;
  final bool enabled;
  final PeelOutcome outcome;
  final VoidCallback onTap;

  @override
  State<_PeelTarget> createState() => _PeelTargetState();
}

class _PeelTargetState extends State<_PeelTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    duration: const Duration(milliseconds: 260),
    vsync: this,
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _tap() {
    _pop
      ..reset()
      ..forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: widget.enabled ? _tap : null,
        child: AnimatedBuilder(
          animation: _pop,
          builder: (_, __) {
            final scale = 1 - 0.08 * _pop.value;
            return Transform.scale(
              scale: scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [widget.palette.glow, Colors.transparent],
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.92, 0.92),
                        end: const Offset(1.1, 1.1),
                        duration: 1800.ms,
                        curve: Curves.easeInOut,
                      ),
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: ThemedPackage(
                      theme: widget.theme,
                      rarity: widget.rarity,
                      size: 240,
                    ),
                  ),
                  if (widget.outcome == PeelOutcome.hit)
                    const _Confetti()
                  else if (widget.outcome == PeelOutcome.miss)
                    const _MissLeaves(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Layer counter that hides the total — players must peel to find out
/// how many layers the package has. Shows the revealed count plus a
/// trailing "???" so the unknown depth is front-of-mind.
class _LayersIndicator extends StatelessWidget {
  const _LayersIndicator({
    required this.revealed,
    required this.total, // kept for backwards compat; ignored in the UI.
    required this.color,
  });
  final int revealed;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cap = revealed.clamp(0, 8);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.layers_outlined,
            size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        for (int i = 0; i < cap; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: color),
              ),
            ),
          ),
        if (revealed > 8)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text('+${revealed - 8}',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        const SizedBox(width: 8),
        Text(
          '·  ???',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 1000),
    vsync: this,
  )..forward();
  final _rng = Random(42);
  late final List<Offset> _dirs =
      List.generate(20, (_) => _rng.randomDir() * (120 + _rng.nextDouble() * 80));
  late final List<Color> _colors = List.generate(
      20,
      (i) => [
            AppColors.coral,
            AppColors.gold,
            AppColors.mint,
            AppColors.violet,
          ][i % 4]);

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
        return Stack(
          children: List.generate(_dirs.length, (i) {
            return Transform.translate(
              offset: _dirs[i] * t,
              child: Opacity(
                opacity: 1 - t,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _colors[i],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MissLeaves extends StatefulWidget {
  const _MissLeaves();
  @override
  State<_MissLeaves> createState() => _MissLeavesState();
}

class _MissLeavesState extends State<_MissLeaves>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 1400),
    vsync: this,
  )..forward();
  final _rng = Random(7);
  late final List<Offset> _drops =
      List.generate(8, (_) => Offset((_rng.nextDouble() - 0.5) * 160, 140));

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
        return Stack(
          alignment: Alignment.center,
          children: List.generate(_drops.length, (i) {
            return Transform.translate(
              offset: _drops[i] * t,
              child: Transform.rotate(
                angle: (i.isEven ? 1 : -1) * t * pi,
                child: Opacity(
                  opacity: 1 - t * 0.8,
                  child: const Text('🍃', style: TextStyle(fontSize: 18)),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

extension on Random {
  Offset randomDir() {
    final a = nextDouble() * 2 * pi;
    return Offset(cos(a), sin(a));
  }
}
