import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/game_state.dart';
import '../../data/models/player.dart';
import '../../data/providers.dart';
import '../../shared/widgets/coin_balance.dart';
import '../../shared/widgets/juicy_button.dart';
import '../../shared/widgets/peel_wordmark.dart';
import 'widgets/live_packages_rail.dart';
import 'widgets/sanctuary_stage.dart';

/// The redesigned Home — "The Sanctuary". One hero package floats on a
/// beam of light above a hex pedestal, framed by a stylised globe. All
/// other live packages live in a compressed horizontal rail below. If
/// the player is currently holding the featured package, a big PEEL NOW
/// CTA routes them into the cinematic opening flow.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? _lastSeenArrival;

  /// If the user taps a rail chip we pin the featured package here.
  /// Cleared automatically whenever the user starts holding a package.
  String? _featuredOverride;

  @override
  Widget build(BuildContext context) {
    final sim = ref.watch(gameStateProvider);
    final s = sim.state;

    final featured = _pickFeatured(s, _featuredOverride);
    // If the user just started holding a package, clear any override
    // so the UI pulls the attention back to the action.
    if (s.userHeldPackage != null && _featuredOverride != null) {
      _featuredOverride = null;
    }

    final arrival = s.lastArrivedToUserAt;
    if (arrival != null && arrival != _lastSeenArrival) {
      _lastSeenArrival = arrival;
      final held = s.userHeldPackage;
      if (held != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (s.hapticsEnabled) HapticFeedback.heavyImpact();
          _showArrivalBanner(context, held);
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: const _TopBar(),
      bottomNavigationBar: const _BottomNav(current: 0),
      body: SafeArea(
        top: false,
        child: featured == null
            ? const _EmptyState()
            : _SanctuaryBody(
                state: s,
                featured: featured,
                onPickFromRail: (id) => setState(() => _featuredOverride = id),
              ),
      ),
    );
  }

  /// Featured = the package currently held by the user (if any), else
  /// the user's manual override from the rail, else the highest-rarity
  /// visible package for their region.
  Package? _pickFeatured(GameState s, String? override) {
    final held = s.userHeldPackage;
    if (held != null) return held;
    final visible = s.visiblePackagesFor(s.user.regionCode);
    if (visible.isEmpty) return null;
    if (override != null) {
      for (final p in visible) {
        if (p.id == override) return p;
      }
    }
    visible.sort((a, b) {
      final r = b.rarity.index.compareTo(a.rarity.index);
      if (r != 0) return r;
      return b.currentHop.startedAt.compareTo(a.currentHop.startedAt);
    });
    return visible.first;
  }

  void _showArrivalBanner(BuildContext context, Package pkg) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: AppColors.coral,
        leading: const Text('🎁', style: TextStyle(fontSize: 28)),
        content: Text(
          '${pkg.regionEmoji} ${pkg.name} just landed in your hands — open it!',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              context.push('/opening/${pkg.id}');
            },
            child: const Text(
              'OPEN NOW',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('Later',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    });
  }
}

class _SanctuaryBody extends StatelessWidget {
  const _SanctuaryBody({
    required this.state,
    required this.featured,
    required this.onPickFromRail,
  });

  final GameState state;
  final Package featured;
  final ValueChanged<String> onPickFromRail;

  @override
  Widget build(BuildContext context) {
    final holder = state.holderOf(featured);
    final isUser = featured.currentHop.holderId == state.user.id &&
        !featured.opened;
    return LayoutBuilder(
      builder: (context, c) {
        final stageH = (c.maxHeight * 0.62).clamp(380.0, 560.0);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              SizedBox(
                height: stageH,
                child: SanctuaryStage(
                  package: featured,
                  holder: holder,
                  isUser: isUser,
                  now: state.now,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _PrimaryCta(
                featured: featured,
                isUser: isUser,
                haptics: state.hapticsEnabled,
              ),
              const SizedBox(height: AppSpacing.md),
              LivePackagesRail(
                packages: state.visiblePackagesFor(state.user.regionCode),
                featuredId: featured.id,
                hapticsEnabled: state.hapticsEnabled,
                onPick: onPickFromRail,
              ),
              const SizedBox(height: AppSpacing.md),
              _MiniFeed(state: state),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.featured,
    required this.isUser,
    required this.haptics,
  });
  final Package featured;
  final bool isUser;
  final bool haptics;

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: SizedBox(
          width: double.infinity,
          child: JuicyButton(
            label: 'OPEN YOUR PACKAGE',
            icon: Icons.lock_open_rounded,
            primary: AppColors.coral,
            onPressed: () {
              if (haptics) HapticFeedback.mediumImpact();
              context.push('/opening/${featured.id}');
            },
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textOnDark,
                side: BorderSide(color: Colors.white.withOpacity(0.14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              icon: const Icon(Icons.public, size: 18),
              label: const Text(
                'Watch on globe',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () => context.push('/map?focus=${featured.id}'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textOnDark,
                side: BorderSide(color: Colors.white.withOpacity(0.14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text(
                'Details',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () => context.push('/package/${featured.id}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFeed extends StatelessWidget {
  const _MiniFeed({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final rows = state.feed.take(3).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LIVE FEED',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 6),
            ...rows.map((e) => _FeedRow(entry: e, state: state)),
          ],
        ),
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.entry, required this.state});
  final FeedEntry entry;
  final GameState state;

  Player _lookup() => entry.playerId == state.user.id
      ? Player(
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
        )
      : AiPlayers.byId(entry.playerId);

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
    final pkg = state.packageById(entry.packageId);
    final hit = entry.layerRevealed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (pkg != null)
            Text(pkg.regionEmoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                    color: AppColors.textOnDark, fontSize: 12),
                children: [
                  TextSpan(
                    text: '${p.name} ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: hit ? 'peeled a layer in ' : 'missed in ',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  TextSpan(text: '${p.city} ${p.flag}'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(hit ? '✨' : '🍃', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            _relative(state.now, entry.at),
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'Seeding the next wave of packages…',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

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
