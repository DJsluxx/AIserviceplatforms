import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/game_state.dart';
import '../../../shared/widgets/themed_package.dart';

/// Horizontal rail showing every OTHER live package (i.e. not the one
/// currently in the sanctuary stage). Tapping a chip swaps that package
/// into the hero slot. Scroll-snap is left to the OS for now — the rail
/// is short enough that gestural scrolling feels native.
class LivePackagesRail extends StatelessWidget {
  const LivePackagesRail({
    super.key,
    required this.packages,
    required this.featuredId,
    required this.hapticsEnabled,
    required this.onPick,
  });

  final List<Package> packages;
  final String featuredId;
  final bool hapticsEnabled;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final others = packages.where((p) => p.id != featuredId).toList();
    if (others.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: others.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == 0) return const _RailLabel();
          final p = others[i - 1];
          return _RailChip(
            package: p,
            onTap: () {
              if (hapticsEnabled) HapticFeedback.selectionClick();
              onPick(p.id);
            },
          );
        },
      ),
    );
  }
}

class _RailLabel extends StatelessWidget {
  const _RailLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OTHER',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'LIVE',
            style: TextStyle(
              color: AppColors.textOnDark,
              fontFamily: 'Fraunces',
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Tap to feature',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailChip extends StatelessWidget {
  const _RailChip({required this.package, required this.onTap});
  final Package package;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = paletteForPackage(package.theme, package.rarity);
    return Semantics(
      button: true,
      label: '${package.regionLabel} ${package.rarity.label} package, '
          'tap to feature',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 78,
          decoration: BoxDecoration(
            color: AppColors.surfaceDarkElevated,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: palette.stroke.withOpacity(0.9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.glow,
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: ThemedPackage(
                      theme: package.theme,
                      rarity: package.rarity,
                      size: 48,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${package.regionEmoji} ${package.layersRevealed}/${package.layersTotal}',
                style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
