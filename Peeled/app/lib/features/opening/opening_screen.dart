import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../home/widgets/beam_of_light.dart';
import '../home/widgets/dust_motes.dart';
import '../home/widgets/hex_pedestal.dart';
import 'widgets/hold_to_peel_ring.dart';
import 'widgets/unwrap_burst.dart';

/// Cinematic one-package opening flow.
///
/// Triggered by:
///   - Arrival banner on Home → `context.push('/opening/:id')`
///   - Rail chip on Home when user is the holder
///   - Notification tap (via deep-link, handled in main.dart)
///
/// Anti-cheat guardrails (UI) — mirrored by the simulator:
///   1. Package must exist in live state.
///   2. Current hop holder must match the logged-in user id.
///   3. Hop must not already be peeled (`peelAttempted`).
///   4. Hop must not be expired.
///   5. A single tap is insufficient — user must sustain contact for the
///      full [HoldToPeelRing.holdDuration] for the attempt to commit.
///   6. Once committed, the attempt is idempotent: `sim.userPeel` short-
///      circuits if the hop already attempted.
class OpeningPackageScreen extends ConsumerStatefulWidget {
  const OpeningPackageScreen({super.key, required this.packageId});
  final String packageId;

  @override
  ConsumerState<OpeningPackageScreen> createState() =>
      _OpeningPackageScreenState();
}

enum _Phase { arming, revealed, miss, opened }

class _OpeningPackageScreenState
    extends ConsumerState<OpeningPackageScreen> {
  _Phase _phase = _Phase.arming;
  bool _burstOn = false;
  int _coinsAtArrival = 0;

  @override
  void initState() {
    super.initState();
    _coinsAtArrival = ref.read(gameStateProvider).state.user.coins;
  }

  void _handleCommit(WidgetRef ref, Package pkg) {
    final sim = ref.read(gameStateProvider);
    final outcome = sim.userPeel(pkg.id);
    setState(() {
      _burstOn = outcome == PeelOutcome.hit;
    });
    Future<void>.delayed(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      final s = ref.read(gameStateProvider).state;
      final post = s.packageById(pkg.id);
      setState(() {
        if (post != null && post.opened) {
          _phase = _Phase.opened;
        } else if (outcome == PeelOutcome.hit) {
          _phase = _Phase.revealed;
        } else {
          _phase = _Phase.miss;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final sim = ref.watch(gameStateProvider);
    final s = sim.state;
    final pkg = s.packageById(widget.packageId);

    if (pkg == null) {
      return const _PackageGoneScaffold();
    }
    final hop = pkg.currentHop;
    final isHolder = hop.holderId == s.user.id;
    final expired = hop.isExpired(s.now);
    final alreadyPeeled = hop.peelAttempted;

    if (!isHolder) {
      return _GuardScaffold(
        title: 'Not your package right now',
        subtitle:
            "The package is with ${s.holderOf(pkg).name} in ${s.holderOf(pkg).city}.",
        cta: 'Back to Sanctuary',
        onCta: () => context.go('/home'),
      );
    }
    // If the user lands here AFTER the hop has already resolved (e.g.
    // tapped a stale notification), show the matching result phase
    // immediately rather than re-arming the ring.
    if (alreadyPeeled && _phase == _Phase.arming) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          if (pkg.opened) {
            _phase = _Phase.opened;
          } else if (hop.outcome == PeelOutcome.hit) {
            _phase = _Phase.revealed;
          } else {
            _phase = _Phase.miss;
          }
        });
      });
    }
    if (pkg.opened) {
      return _GuardScaffold(
        title: 'This package is already open',
        subtitle: 'A fresh one is on its way to the globe.',
        cta: 'Back to Sanctuary',
        onCta: () => context.go('/home'),
      );
    }
    if (expired) {
      return _GuardScaffold(
        title: 'Your window closed',
        subtitle:
            'The package hopped on. Watch the globe to see where it lands.',
        cta: 'Open globe',
        onCta: () => context.go('/map?focus=${pkg.id}'),
      );
    }

    final palette = paletteForPackage(pkg.theme, pkg.rarity);
    final coinsNow = s.user.coins;
    final coinsGained =
        (coinsNow - _coinsAtArrival).clamp(0, 1000000).toInt();

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: dimmed globe-less version of the sanctuary beam.
          Positioned.fill(child: _OpeningBackdrop(accent: palette.fill)),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: MediaQuery.of(context).size.height * 0.72,
            child: BeamOfLight(
              accent: palette.fill,
              topWidth: 44,
              bottomWidth: MediaQuery.of(context).size.width * 0.75,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: MediaQuery.of(context).size.height * 0.72,
            child: DustMotes(accent: palette.fill),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.42,
            child: HexPedestal(accent: palette.fill, pulse: 0.0),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopRow(
                  pkg: pkg,
                  now: s.now,
                  coins: coinsNow,
                ),
                const SizedBox(height: AppSpacing.md),
                _Instruction(phase: _phase, rarity: pkg.rarity),
                const Spacer(),
                _CentreStage(
                  pkg: pkg,
                  phase: _phase,
                  accent: palette.fill,
                  burstOn: _burstOn,
                  hapticsEnabled: s.hapticsEnabled,
                  alreadyPeeled: alreadyPeeled,
                  onCommit: () => _handleCommit(ref, pkg),
                  onBurstEnd: () => setState(() => _burstOn = false),
                ),
                const Spacer(flex: 2),
                _BottomCards(
                  pkg: pkg,
                  phase: _phase,
                  coinsGained: coinsGained,
                  onDone: () {
                    sim.notifications.cancelAll();
                    context.go('/home');
                  },
                  onPlayAgain: () => context.go('/home'),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textOnDark),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/home'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpeningBackdrop extends StatelessWidget {
  const _OpeningBackdrop({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.1,
          colors: [
            accent.withOpacity(0.18),
            const Color(0xFF08091A),
            const Color(0xFF04050F),
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.pkg,
    required this.now,
    required this.coins,
  });
  final Package pkg;
  final DateTime now;
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xs, AppSpacing.md, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pkg.regionEmoji} ${pkg.name}',
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontFamily: 'Fraunces',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    LiveCountdown(
                      remaining: pkg.currentHop.remaining(now),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          CoinBalance(coins: coins),
        ],
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  const _Instruction({required this.phase, required this.rarity});
  final _Phase phase;
  final PackageRarity rarity;

  @override
  Widget build(BuildContext context) {
    String label;
    switch (phase) {
      case _Phase.arming:
        label = 'HOLD TO PEEL';
        break;
      case _Phase.revealed:
        label = 'LAYER REVEALED';
        break;
      case _Phase.miss:
        label = 'NO LUCK THIS TIME';
        break;
      case _Phase.opened:
        label = 'YOU OPENED IT';
        break;
    }
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textOnDark,
        fontWeight: FontWeight.w900,
        fontSize: 11,
        letterSpacing: 3,
      ),
    );
  }
}

class _CentreStage extends StatelessWidget {
  const _CentreStage({
    required this.pkg,
    required this.phase,
    required this.accent,
    required this.burstOn,
    required this.hapticsEnabled,
    required this.alreadyPeeled,
    required this.onCommit,
    required this.onBurstEnd,
  });

  final Package pkg;
  final _Phase phase;
  final Color accent;
  final bool burstOn;
  final bool hapticsEnabled;
  final bool alreadyPeeled;
  final VoidCallback onCommit;
  final VoidCallback onBurstEnd;

  @override
  Widget build(BuildContext context) {
    final canHold = phase == _Phase.arming && !alreadyPeeled;
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          HoldToPeelRing(
            accent: accent,
            enabled: canHold,
            haptics: hapticsEnabled,
            onCommit: onCommit,
            size: 270,
            child: SizedBox(
              width: 200,
              height: 200,
              child: ThemedPackage(
                theme: pkg.theme,
                rarity: pkg.rarity,
                size: 200,
              ),
            ),
          ),
          if (burstOn)
            Positioned.fill(
              child: UnwrapBurst(accent: accent, onEnd: onBurstEnd),
            ),
        ],
      ),
    );
  }
}

class _BottomCards extends StatelessWidget {
  const _BottomCards({
    required this.pkg,
    required this.phase,
    required this.coinsGained,
    required this.onDone,
    required this.onPlayAgain,
  });

  final Package pkg;
  final _Phase phase;
  final int coinsGained;
  final VoidCallback onDone;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case _Phase.arming:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            'Press and hold the package. Lift off and nothing happens — this locks out bots and replays.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        );
      case _Phase.revealed:
        return _ResultCard(
          accent: AppColors.mint,
          emoji: '✨',
          title: pkg.hints.isNotEmpty ? pkg.hints.last : 'A layer peels away.',
          reward: coinsGained,
          primary: 'Back to Sanctuary',
          onPrimary: onDone,
        );
      case _Phase.miss:
        return _ResultCard(
          accent: AppColors.kraft,
          emoji: '🍃',
          title: 'The package slips away untouched.',
          reward: 0,
          primary: 'Watch it travel',
          onPrimary: onPlayAgain,
        );
      case _Phase.opened:
        return _ResultCard(
          accent: AppColors.gold,
          emoji: '🏆',
          title: 'Final layer peeled. The package is yours.',
          reward: coinsGained,
          primary: 'Collect and continue',
          onPrimary: onDone,
          huge: true,
        );
    }
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.accent,
    required this.emoji,
    required this.title,
    required this.reward,
    required this.primary,
    required this.onPrimary,
    this.huge = false,
  });

  final Color accent;
  final String emoji;
  final String title;
  final int reward;
  final String primary;
  final VoidCallback onPrimary;
  final bool huge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceDarkElevated.withOpacity(0.92),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: accent.withOpacity(0.55)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.25),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: huge ? 44 : 28)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textOnDark,
              fontFamily: 'Fraunces',
              fontSize: huge ? 22 : 18,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          if (reward > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _RewardBadge(coins: reward, accent: accent),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: JuicyButton(
              label: primary,
              primary: accent,
              onPressed: onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardBadge extends StatelessWidget {
  const _RewardBadge({required this.coins, required this.accent});
  final int coins;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: accent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            '+$coins coins',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardScaffold extends StatelessWidget {
  const _GuardScaffold({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onCta,
  });
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔒', style: TextStyle(fontSize: 56)),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontFamily: 'Fraunces',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: JuicyButton(
                  label: cta,
                  primary: AppColors.coral,
                  onPressed: onCta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageGoneScaffold extends StatelessWidget {
  const _PackageGoneScaffold();
  @override
  Widget build(BuildContext context) {
    Future<void>.delayed(Duration.zero, () {
      if (context.mounted) context.go('/home');
    });
    return const Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SizedBox.shrink(),
    );
  }
}
