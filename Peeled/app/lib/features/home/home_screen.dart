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
import '../../shared/widgets/peel_wordmark.dart';
import '../../shared/widgets/player_avatar.dart';

/// The Home screen is the Live Package Tracker. It always shows where the
/// package is *right now* — with a countdown, a peel-progress ring, and a
/// live feed below. When the package lands in your hands, the card flips
/// into a huge "PEEL" CTA with a haptic + banner. That arrival moment is
/// the whole hook of the game.
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

    // Fire the arrival banner exactly once per arrival.
    final arrival = s.lastArrivedToUserAt;
    if (arrival != null && arrival != _lastSeenArrival) {
      _lastSeenArrival = arrival;
      if (s.userHoldsPackage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (s.hapticsEnabled) HapticFeedback.heavyImpact();
          _showArrivalBanner(context);
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: const _HomeAppBar(),
      bottomNavigationBar: const _BottomNav(current: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
        children: [
          _TrackerCard(state: s, simulator: sim),
          const SizedBox(height: AppSpacing.lg),
          _PackageProgressStrip(state: s),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
            title: 'Live feed',
            trailing: Text(
              '${s.feed.length} events',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (s.feed.isEmpty)
            const _FeedEmpty()
          else
            ...s.feed.take(12).map((e) => _FeedRow(entry: e, state: s)),
        ],
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
          'The package is in your hands — peel before the clock runs out!',
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
              context.push('/peel/now');
            },
            child: const Text(
              'PEEL NOW',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text(
              'Later',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _HomeAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sim = ref.watch(gameStateProvider);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: Row(
          children: [
            const PeelWordmark(height: 30, showAccent: true),
            const Spacer(),
            CoinBalance(coins: sim.state.user.coins),
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

/// The hero card. When an AI holds it, it shows name/city/timer/progress.
/// When the user holds it, it morphs into a giant "TAP TO PEEL" button.
class _TrackerCard extends StatelessWidget {
  const _TrackerCard({required this.state, required this.simulator});

  final GameState state;
  final GameSimulator simulator;

  @override
  Widget build(BuildContext context) {
    final hop = state.package.currentHop;
    final holder = state.currentHolder;
    final remaining = hop.remaining(state.now);
    final rarity = state.package.rarity;
    final palette = AppColors.forRarity(rarity.token);

    if (state.userHoldsPackage) {
      return _YourTurnCard(state: state);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceDarkElevated,
            AppColors.surfaceDarkElevated.withOpacity(0.7),
          ],
        ),
        border: Border.all(color: palette.glow),
        boxShadow: [
          BoxShadow(color: palette.glow, blurRadius: 24, spreadRadius: -4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RarityChip(rarity: rarity),
              const Spacer(),
              Text(
                '${state.package.layersRevealed}/? layers',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              PlayerAvatar(emoji: holder.avatar, size: 68, tint: palette.fill),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Currently with',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      holder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textOnDark,
                        fontFamily: 'Fraunces',
                        fontSize: 24,
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
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  color: AppColors.textMuted, size: 18),
              const SizedBox(width: 6),
              LiveCountdown(
                remaining: remaining,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${_compact(hop.peelsDone)} / ${_compact(hop.peelsRequired)} peels',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: hop.peelProgress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation(palette.fill),
            ),
          ),
        ],
      ),
    );
  }
}

class _YourTurnCard extends StatelessWidget {
  const _YourTurnCard({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final hop = state.package.currentHop;
    final remaining = hop.remaining(state.now);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
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
              letterSpacing: 2,
            ),
          ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 400.ms).then(delay: 1200.ms).fadeOut(duration: 300.ms).then().fadeIn(duration: 400.ms),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'The package is in your hands',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Fraunces',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              LiveCountdown(
                remaining: remaining,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Fraunces',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
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

class _PackageProgressStrip extends StatelessWidget {
  const _PackageProgressStrip({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final pkg = state.package;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AppColors.surfaceDarkElevated.withOpacity(0.6),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined, color: AppColors.coral),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pkg.hints.isEmpty
                      ? 'No layers peeled yet. The package is untouched.'
                      : pkg.hints.last,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hints so far: ${pkg.hints.length}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
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

class _RarityChip extends StatelessWidget {
  const _RarityChip({required this.rarity});
  final PackageRarity rarity;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.forRarity(rarity.token);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.fill.withOpacity(0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.stroke),
      ),
      child: Text(
        rarity.label.toUpperCase(),
        style: TextStyle(
          color: palette.fill,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textOnDark,
            fontFamily: 'Fraunces',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

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
        'Waiting for the first hop… the package is just about to move.',
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
        avatar: state.user.avatar,
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
    final revealed = entry.layerRevealed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          PlayerAvatar(emoji: p.avatar, size: 38),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
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
                        text: revealed
                            ? 'peeled a layer in '
                            : 'passed the package in ',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      TextSpan(
                        text: '${p.city} ${p.flag}',
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_compact(entry.peelsDone)} peels • ${_relative(state.now, entry.at)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (revealed)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                color: AppColors.mint.withOpacity(0.15),
                border: Border.all(color: AppColors.mint.withOpacity(0.5)),
              ),
              child: const Text(
                'LAYER',
                style: TextStyle(
                  color: AppColors.mint,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return n.toString();
}
