import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/providers.dart';
import '../../shared/widgets/coin_balance.dart';
import '../../shared/widgets/juicy_button.dart';

/// Shop is intentionally a "coming soon" stub while we focus on the core
/// peel loop. Cosmetics (avatar frames, package skins) will be the first
/// category once we monetise.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(gameStateProvider).state.user.coins;
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
          'Shop',
          style:
              TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: CoinBalance(coins: coins),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🛍️', style: TextStyle(fontSize: 80)),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Cosmetics coming soon',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textOnDark,
                fontFamily: 'Fraunces',
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Spend coins on avatar frames, package skins and emoji packs. '
              'Keep peeling — a new season drops every month.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            JuicyButton(
              label: 'Back to live feed',
              primary: AppColors.coral,
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      ),
    );
  }
}
