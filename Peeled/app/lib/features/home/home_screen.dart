import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../shared/widgets/juicy_button.dart';
import '../../shared/widgets/live_countdown.dart';
import '../../shared/widgets/package_sprite.dart';
import '../../shared/widgets/peel_wordmark.dart';
import '../../shared/widgets/player_avatar.dart';

/// Home is the hero screen. The package is the star — enormous,
/// rarity-glowing, centered. Details around it. When it's your turn
/// there's one single giant PEEL button.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? _lastSeenArrival;

  @override
  Widget build(BuildContext context) {
    final sim = ref.watch(gameStateProvider);
    final s = sim.state;

    // Fire arrival banner + heavy haptic exactly once when the package
    // lands in the user's hands.
    final arrival = s.lastArrivedToUserAt;
    if (arrival != null &&
        arrival != _lastSeenArrival &&
        s.userHoldsPackage) {
      _lastSeenArrival = arrival;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (s.hapticsEnabled) HapticFeedback.heavyImpact();
        _showArrivalBanner(context);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: const _TopBar(),
      bottomNavigationBar: const _BottomNav(current: 0),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
          children: [
            _HeroPackage(state: s),
            const SizedBox(height: AppSpacing.md),
            _DetailsCard(state: s),
            const SizedBox(height: AppSpacing.md),
            if (s.userHoldsPackage && !s.package.currentHop.peelAttempted)
              _PeelCta(sim: sim, state: s)
            else
              _OutcomeBanner(state: s),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Text(
                  'Live feed',
                  style: TextStyle(
                    color: AppColors.textOnDark,
                    fontFamily: 'Fraunces',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/map'),
                  child: const Text(
                    'See globe',
                    style: TextStyle(color: AppColors.coral),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (s.feed.isEmpty)
              const _FeedEmpty()
            else
              ...s.feed.take(8).map((e) => _FeedRow(entry: e, state: s)),
          ],
        ),
      ),
    );
  }

  void _showArrivalBanner(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: AppColors.coral,
        leading: const Text('🎁', style: TextStyle(fontSize: 28)),
        content: const Text(
          'The package just landed in your hands. Tap to peel!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
            },
            child: const Text(
              'GOT IT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    });
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _TopBar();

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(gameStateProvider).state.user.coins;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: Row(
          children: [
            const PeelWordmark(height: 30, showAccent: true),
            const Spacer(),
            CoinBalance(coins: coins),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.settings_outlined,
                  color: AppColors.textOnDark),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero package visual
// ---------------------------------------------------------------------------

class _HeroPackage extends StatelessWidget {
  const _HeroPackage({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final rarity = state.package.rarity;
    final palette = AppColors.forRarity(rarity.token);
    return SizedBox(
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background glow pulse — rarity-coloured.
          Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [palette.glow, Colors.transparent],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.1, 1.1),
                duration: 1800.ms,
                curve: Curves.easeInOut,
              ),
          // Rotating rarity ring.
          _RarityRing(color: palette.stroke),
          // Floating package sprite. Wrapped in SizedBox because
          // PackageSprite itself has an `animate` field that would
          // otherwise shadow flutter_animate's extension.
          SizedBox(
            width: 220,
            height: 220,
            child: PackageSprite(rarity: rarity.token, size: 220),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: -6, end: 6, duration: 2200.ms, curve: Curves.easeInOut),
          // Rarity chip pinned bottom.
          Align(
            alignment: Alignment.bottomCenter,
            child: _RarityChip(rarity: rarity),
          ),
          // Layer pips pinned top.
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _LayerPips(
                revealed: state.package.layersRevealed,
                total: state.package.layersTotal,
                accent: palette.fill,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RarityRing extends StatelessWidget {
  const _RarityRing({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      height: 270,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: CustomPaint(
        painter: _DashedRingPainter(color: color.withOpacity(0.6)),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .rotate(duration: 24.seconds, curve: Curves.linear);
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    final r = size.width / 2 - 1;
    final center = size.center(Offset.zero);
    const segments = 48;
    for (int i = 0; i < segments; i++) {
      if (i.isOdd) continue;
      final a0 = (2 * pi) * i / segments;
      final a1 = (2 * pi) * (i + 1) / segments;
      final p0 = center + Offset(cos(a0), sin(a0)) * r;
      final p1 = center + Offset(cos(a1), sin(a1)) * r;
      canvas.drawLine(p0, p1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) => old.color != color;
}

class _RarityChip extends StatelessWidget {
  const _RarityChip({required this.rarity});
  final PackageRarity rarity;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.forRarity(rarity.token);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.ink.withOpacity(0.8),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.stroke, width: 2),
      ),
      child: Text(
        '${rarity.label.toUpperCase()} PACKAGE',
        style: TextStyle(
          color: palette.fill,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _LayerPips extends StatelessWidget {
  const _LayerPips({
    required this.revealed,
    required this.total,
    required this.accent,
  });
  final int revealed;
  final int total;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // We show actual layersTotal pips so the player gets a sense of
    // depth, but it's still partially mysterious because the dots
    // don't tell them what's inside each layer.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final on = i < revealed;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? accent : Colors.white.withOpacity(0.12),
            border: Border.all(
              color: on ? accent : Colors.white.withOpacity(0.2),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Details card — who has it, where, time left
// ---------------------------------------------------------------------------

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final hop = state.package.currentHop;
    final holder = state.currentHolder;
    final previous = state.previousHolder;
    final isYou = state.userHoldsPackage;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDarkElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              PlayerAvatar(
                emoji: holder.avatarEmoji,
                imageUrl: holder.avatarUrl,
                size: 52,
                ring: isYou,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IN THE HANDS OF',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isYou ? 'You' : holder.name,
                      style: const TextStyle(
                        color: AppColors.textOnDark,
                        fontFamily: 'Fraunces',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${holder.city} ${holder.flag}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  LiveCountdown(
                    remaining: hop.remaining(state.now),
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (previous != null) ...[
            const Divider(color: Colors.white12, height: AppSpacing.lg),
            Row(
              children: [
                const Icon(Icons.south_east_rounded,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Came from ${previous.city} ${previous.flag}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (state.package.hints.isNotEmpty)
                  Flexible(
                    child: Text(
                      '“${state.package.hints.last}”',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textOnDark,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Peel CTA (only shown when user holds + hasn't attempted)
// ---------------------------------------------------------------------------

class _PeelCta extends StatelessWidget {
  const _PeelCta({required this.sim, required this.state});
  final GameSimulator sim;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.coral, AppColors.violet],
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x66FF6B57), blurRadius: 40, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "🎁 IT'S WITH YOU",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 2.4,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 600.ms),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'You get one peel.\nFeeling lucky?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Fraunces',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          JuicyButton(
            label: 'PEEL NOW',
            icon: Icons.touch_app_rounded,
            primary: Colors.white,
            foreground: AppColors.coral,
            onPressed: () => context.push('/peel/now'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Outcome banner (after any attempt this hop)
// ---------------------------------------------------------------------------

class _OutcomeBanner extends StatelessWidget {
  const _OutcomeBanner({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final hop = state.package.currentHop;
    final isYou = state.userHoldsPackage;

    if (!hop.peelAttempted) {
      // AI holder, still thinking.
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceDarkElevated.withOpacity(0.7),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_bottom_rounded,
                size: 18, color: AppColors.textMuted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Waiting for a peel attempt…',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final hit = hop.outcome == PeelOutcome.hit;
    final bg = hit
        ? AppColors.mint.withOpacity(0.15)
        : AppColors.textMuted.withOpacity(0.12);
    final border = hit ? AppColors.mint : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(
            hit ? '✨' : '🍃',
            style: const TextStyle(fontSize: 26),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hit
                      ? (isYou ? 'You peeled a layer!' : 'A layer was revealed')
                      : (isYou ? 'No layer this time.' : 'Peel missed'),
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  hit
                      ? 'Package is hopping away…'
                      : 'The package will pass along soon.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live feed
// ---------------------------------------------------------------------------

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: const Text(
        'Waiting for the first peel attempt…',
        style: TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.entry, required this.state});
  final FeedEntry entry;
  final GameState state;

  Player _lookup() {
    if (entry.playerId == state.user.id) {
      return Player(
        id: state.user.id,
        name: 'You',
        avatarEmoji: state.user.avatarEmoji,
        avatarUrl: state.user.avatarUrl,
        city: state.user.city,
        country: '',
        flag: state.user.flag,
        lat: 0,
        lon: 0,
        isUser: true,
      );
    }
    return AiPlayers.byId(entry.playerId);
  }

  String _relative(DateTime now, DateTime at) {
    final d = now.difference(at);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final p = _lookup();
    final hit = entry.layerRevealed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          PlayerAvatar(emoji: p.avatarEmoji, imageUrl: p.avatarUrl, size: 34),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(
                    text: '${p.name} ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: hit
                        ? 'peeled a layer in '
                        : 'missed a peel in ',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  TextSpan(text: '${p.city} ${p.flag}'),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (hit)
            const Text('✨', style: TextStyle(fontSize: 14))
          else
            const Text('🍃', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            _relative(state.now, entry.at),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: current,
      backgroundColor: AppColors.surfaceDarkElevated,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.radar_outlined), label: 'Live'),
        NavigationDestination(icon: Icon(Icons.public), label: 'Globe'),
        NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined), label: 'Ranks'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'Me'),
      ],
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/map');
            break;
          case 2:
            context.go('/leaderboard');
            break;
          case 3:
            context.go('/profile');
            break;
        }
      },
    );
  }
}
