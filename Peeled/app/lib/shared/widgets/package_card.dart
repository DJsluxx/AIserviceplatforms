import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/package_model.dart';
import 'package_sprite.dart';

/// Inbox card — shows a package sprite with rarity glow, progress pips,
/// and remaining-time pill.
class PackageCard extends StatelessWidget {
  const PackageCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final InboxItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pkg = item.package;
    final palette = AppColors.forRarity(pkg.rarity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surfaceDarkElevated,
                Color.lerp(AppColors.surfaceDarkElevated, palette.fill, 0.16)!,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: palette.fill.withOpacity(0.35), width: 1.5),
            boxShadow: AppElevation.card,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              PackageSprite(rarity: pkg.rarity, size: 96, animate: true),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pkg.rarity.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: palette.fill,
                        fontSize: 12,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pkg.theme ?? 'Mystery Package',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontFamily: 'Fraunces'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _LayerPips(total: pkg.totalLayers, peeled: pkg.peeledLayers,
                        color: palette.fill),
                    const SizedBox(height: AppSpacing.xs),
                    _TimePill(seconds: item.secondsRemaining),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayerPips extends StatelessWidget {
  const _LayerPips({required this.total, required this.peeled, required this.color});
  final int total;
  final int peeled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pips = total > 18 ? 18 : total;
    final peeledVisible = (peeled * pips / (total == 0 ? 1 : total)).round();
    return Row(
      children: List.generate(pips, (i) {
        final on = i < peeledVisible;
        return Container(
          width: 12,
          height: 6,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: on ? color : color.withOpacity(0.22),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final color = seconds < 10 ? AppColors.danger : AppColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$seconds s left',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
