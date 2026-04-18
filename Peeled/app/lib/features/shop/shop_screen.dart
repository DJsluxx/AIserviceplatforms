import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/juicy_button.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _Tile(
            icon: Icons.star,
            title: 'PEELED Plus',
            body: 'Unlimited peels · 2× XP · exclusive cosmetics',
            priceLabel: '\$4.99/mo',
            primary: AppColors.gold,
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.md),
          _Tile(
            icon: Icons.savings,
            title: 'Pocket Coins',
            body: '120 coins',
            priceLabel: '\$0.99',
            primary: AppColors.coral,
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.md),
          _Tile(
            icon: Icons.confirmation_number,
            title: 'Prize Tokens x5',
            body: 'Guaranteed legendary token spins',
            priceLabel: '\$2.99',
            primary: AppColors.violet,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.body,
    required this.priceLabel,
    required this.primary,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String body;
  final String priceLabel;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDarkElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: primary, size: 32),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(body,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.md),
          JuicyButton(
            label: priceLabel,
            primary: primary,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
