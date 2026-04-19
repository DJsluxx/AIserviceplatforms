import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/providers.dart';
import '../../shared/widgets/coin_balance.dart';
import '../../shared/widgets/juicy_button.dart';
import '../../shared/widgets/player_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sim = ref.watch(gameStateProvider);
    final u = sim.state.user;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile',
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
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Column(
              children: [
                PlayerAvatar(
                    emoji: u.avatar, size: 96, tint: AppColors.coral, ring: true),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '@${u.handle}',
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontFamily: 'Fraunces',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${u.city} ${u.flag}',
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _StatsGrid(
            stats: [
              _Stat(label: 'Coins', value: u.coins, icon: '🪙'),
              _Stat(label: 'Packages', value: u.packagesOpened, icon: '📦'),
              _Stat(label: 'Layers', value: u.layersPeeled, icon: '✨'),
              _Stat(label: 'Total peels', value: u.totalPeels, icon: '🫳'),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          JuicyButton(
            label: 'Settings',
            icon: Icons.settings_outlined,
            primary: AppColors.violet,
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(height: AppSpacing.sm),
          JuicyButton(
            label: 'Sign out',
            primary: AppColors.kraft,
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}

class _Stat {
  const _Stat({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
  final String icon;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.8,
      children: stats.map((s) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceDarkElevated,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(s.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                _formatInt(s.value),
                style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontFamily: 'Fraunces',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                s.label,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
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
