import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/game_state.dart';
import '../../data/models/player.dart';
import '../../data/providers.dart';
import '../../data/services/game_simulator.dart';
import '../../shared/widgets/coin_balance.dart';
import '../../shared/widgets/package_card.dart';
import '../../shared/widgets/peel_wordmark.dart';

/// Home is a vertical feed of packages available in the player's
/// region. Each package gets its own big self-contained [PackageCard]:
/// themed hero art, climbing peel counter, layer pips, mini-globe of
/// last ~5 cities, holder strip, and a PEEL CTA when the package is
/// in the player's hands.
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

    // Arrival banner fires once per arrival event, regardless of which
    // package landed in the player's hands.
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

    final visible = s.visiblePackagesFor(s.user.regionCode);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: const _TopBar(),
      bottomNavigationBar: const _BottomNav(current: 0),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
            SliverToBoxAdapter(
              child: _RegionHeader(regionCode: s.user.regionCode),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, 0),
              sliver: SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (_, i) {
                  final pkg = visible[i];
                  return _PackageCardForState(state: s, package: pkg);
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            SliverToBoxAdapter(child: _FeedSection(state: s)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }

  void _showArrivalBanner(BuildContext context, Package pkg) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: AppColors.coral,
        leading: const Text('🎁', style: TextStyle(fontSize: 28)),
        content: Text(
          '${pkg.regionEmoji} ${pkg.name} just landed in your hands — tap to peel!',
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
              context.push('/peel/${pkg.id}');
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

class _PackageCardForState extends StatelessWidget {
  const _PackageCardForState({required this.state, required this.package});
  final GameState state;
  final Package package;

  /// Ordered oldest → newest up to ~5 most-recent holders for this
  /// package's hop chain. Used by the mini-globe in the card.
  List<Player> _recentHolders() {
    final hops = package.hops;
    final tail = hops.length <= 5 ? hops : hops.sublist(hops.length - 5);
    return [
      for (final h in tail)
        h.holderId == state.user.id
            ? _userPlayerFor(state)
            : AiPlayers.byId(h.holderId)
    ];
  }

  @override
  Widget build(BuildContext context) {
    final holder = state.holderOf(package);
    final previous = state.previousHolderOf(package);
    final isYours = package.currentHop.holderId == state.user.id;
    return PackageCard(
      package: package,
      holder: holder,
      previousHolder: previous,
      recentHolders: _recentHolders(),
      now: state.now,
      isYours: isYours,
    );
  }
}

Player _userPlayerFor(GameState s) => Player(
      id: s.user.id,
      name: 'You',
      avatarEmoji: s.user.avatarEmoji,
      avatarUrl: s.user.avatarUrl,
      city: s.user.city,
      country: '',
      flag: s.user.flag,
      lat: 0,
      lon: 0,
      isUser: true,
    );

class _RegionHeader extends StatelessWidget {
  const _RegionHeader({required this.regionCode});
  final String regionCode;

  @override
  Widget build(BuildContext context) {
    final label = _regionLabel(regionCode);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.radar_outlined,
              color: AppColors.coral, size: 16),
          const SizedBox(width: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              children: [
                const TextSpan(
                    text: 'Live in your region · ',
                    style: TextStyle(color: AppColors.textMuted)),
                TextSpan(
                    text: label,
                    style: const TextStyle(color: AppColors.textOnDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _regionLabel(String code) {
  switch (code) {
    case 'usa':
      return '🇺🇸 United States';
    case 'eu':
      return '🇪🇺 Europe';
    case 'asia':
      return '🌏 Asia';
    default:
      return '🌍 Worldwide';
  }
}

class _FeedSection extends StatelessWidget {
  const _FeedSection({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              Text(
                '${state.feed.length} events',
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (state.feed.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: const Text(
                'Waiting for the first peel attempt…',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            ...state.feed.take(10).map((e) => _FeedRow(entry: e, state: state)),
        ],
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.entry, required this.state});
  final FeedEntry entry;
  final GameState state;

  Player _lookup() => entry.playerId == state.user.id
      ? _userPlayerFor(state)
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (pkg != null)
            Text(pkg.regionEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                    color: AppColors.textOnDark, fontSize: 13),
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(hit ? '✨' : '🍃', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            _relative(state.now, entry.at),
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
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
