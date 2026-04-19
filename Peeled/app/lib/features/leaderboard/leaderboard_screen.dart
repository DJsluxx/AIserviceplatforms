import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/player.dart';
import '../../data/providers.dart';
import '../../shared/widgets/coin_balance.dart';
import '../../shared/widgets/player_avatar.dart';

/// Leaderboard. Right now there's no backend, so we synthesize stable
/// per-player coin totals from player id hashes — gives a convincing
/// global ranking to play against while we build a real backend.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sim = ref.watch(gameStateProvider);
    final u = sim.state.user;

    final rows = <_Row>[
      _Row(
        id: u.id,
        name: '@${u.handle} (you)',
        avatar: u.avatar,
        subtitle: '${u.city} ${u.flag}',
        coins: u.coins,
        isYou: true,
      ),
      for (final p in AiPlayers.all)
        _Row(
          id: p.id,
          name: p.name,
          avatar: p.avatar,
          subtitle: '${p.city} ${p.flag}',
          coins: _fakeCoinsFor(p.id),
        ),
    ]..sort((a, b) => b.coins.compareTo(a.coins));

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
          'Global Ranks',
          style: TextStyle(
              fontFamily: 'Fraunces', fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: CoinBalance(coins: u.coins),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) => _LeaderboardTile(row: rows[i], rank: i + 1),
      ),
    );
  }
}

class _Row {
  _Row({
    required this.id,
    required this.name,
    required this.avatar,
    required this.subtitle,
    required this.coins,
    this.isYou = false,
  });
  final String id;
  final String name;
  final String avatar;
  final String subtitle;
  final int coins;
  final bool isYou;
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.row, required this.rank});
  final _Row row;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '#$rank';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: row.isYou
            ? AppColors.coral.withOpacity(0.15)
            : AppColors.surfaceDarkElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: row.isYou
              ? AppColors.coral
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              medal,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          PlayerAvatar(emoji: row.avatar, size: 42),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  row.subtitle,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${_formatInt(row.coins)} 🪙',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

int _fakeCoinsFor(String id) {
  // Stable pseudo-random per id so the board doesn't jitter on rebuild.
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return 500 + (h % 4500);
}

String _formatInt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
