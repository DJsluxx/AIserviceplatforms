import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/player.dart';
import '../../data/providers.dart';
import '../../shared/widgets/coin_balance.dart';
import '../../shared/widgets/player_avatar.dart';

/// Global ranks. Sorted by total peel count (number of peel attempts —
/// successful or not). Real players first, AI placeholders alongside
/// with stable pseudo-random totals so the board doesn't jitter on
/// every rebuild.
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
        avatarEmoji: u.avatarEmoji,
        avatarUrl: u.avatarUrl,
        subtitle: '${u.city} ${u.flag}',
        peels: u.totalPeels,
        isYou: true,
      ),
      for (final p in AiPlayers.all)
        _Row(
          id: p.id,
          name: p.name,
          avatarEmoji: p.avatarEmoji,
          avatarUrl: p.avatarUrl,
          subtitle: '${p.city} ${p.flag}',
          peels: _fakePeelsFor(p.id),
        ),
    ]..sort((a, b) => b.peels.compareTo(a.peels));

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
          style:
              TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: CoinBalance(coins: u.coins),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded,
                    color: AppColors.textMuted, size: 14),
                SizedBox(width: 6),
                Text(
                  'Ranked by total peel attempts',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) =>
                  _LeaderboardTile(row: rows[i], rank: i + 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row {
  _Row({
    required this.id,
    required this.name,
    required this.avatarEmoji,
    required this.avatarUrl,
    required this.subtitle,
    required this.peels,
    this.isYou = false,
  });
  final String id;
  final String name;
  final String avatarEmoji;
  final String avatarUrl;
  final String subtitle;
  final int peels;
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
          color: row.isYou ? AppColors.coral : Colors.white.withOpacity(0.05),
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
          PlayerAvatar(
            emoji: row.avatarEmoji,
            imageUrl: row.avatarUrl,
            size: 42,
          ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatInt(row.peels),
                style: const TextStyle(
                  color: AppColors.coral,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Text(
                'PEELS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stable pseudo-random per-AI peel total so the board doesn't jitter
/// on rebuild.
int _fakePeelsFor(String id) {
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return 50 + (h % 950);
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
