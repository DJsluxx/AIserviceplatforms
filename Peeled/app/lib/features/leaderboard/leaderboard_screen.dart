import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 20,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final rank = i + 1;
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceDarkElevated,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: rank <= 3
                      ? AppColors.gold
                      : AppColors.kraft.withOpacity(0.3),
                  child: Text('$rank',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text('Player $rank',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Text('${(1000 - i * 37)} XP',
                    style: const TextStyle(
                        color: AppColors.gold, fontWeight: FontWeight.w700)),
              ],
            ),
          );
        },
      ),
    );
  }
}
