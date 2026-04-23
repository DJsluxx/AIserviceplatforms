import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/game_state.dart';
import '../../../data/models/player.dart';
import '../../../shared/widgets/live_countdown.dart';
import '../../../shared/widgets/themed_package.dart';
import 'beam_of_light.dart';
import 'dust_motes.dart';
import 'floating_package.dart';
import 'hex_pedestal.dart';
import 'holder_chip.dart';
import 'sanctuary_background.dart';

/// The signature visual of the home screen: the stylised globe + beam of
/// light + spinning floating package + hex pedestal + holder chip, all
/// composed together. Sized to fill whatever parent box it's given.
class SanctuaryStage extends StatefulWidget {
  const SanctuaryStage({
    super.key,
    required this.package,
    required this.holder,
    required this.isUser,
    required this.now,
  });

  final Package package;
  final Player holder;
  final bool isUser;
  final DateTime now;

  @override
  State<SanctuaryStage> createState() => _SanctuaryStageState();
}

class _SanctuaryStageState extends State<SanctuaryStage>
    with SingleTickerProviderStateMixin {
  // Drives pedestal pulse (expanding rings).
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pkg = widget.package;
    final palette = paletteForPackage(pkg.theme, pkg.rarity);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final packageSize = (w * 0.46).clamp(160.0, 240.0);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background — globe + starfield + halo.
              SanctuaryBackground(accent: palette.fill),

              // Beam of light (covers the top 70% of the stage so its
              // gradient fades into the pedestal area).
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: h * 0.74,
                child: BeamOfLight(
                  accent: palette.fill,
                  topWidth: 52,
                  bottomWidth: w * 0.72,
                ),
              ),

              // Dust motes inside the beam.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: h * 0.74,
                child: DustMotes(accent: palette.fill),
              ),

              // Pedestal — lives in the lower half.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: h * 0.45,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => HexPedestal(
                    accent: palette.fill,
                    pulse: _pulse.value,
                  ),
                ),
              ),

              // Floating package — centred on the pedestal.
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(0, -0.12),
                  child: FloatingPackage(
                    theme: pkg.theme,
                    rarity: pkg.rarity,
                    size: packageSize,
                  ),
                ),
              ),

              // Rarity tag — top left.
              Positioned(
                left: AppSpacing.md,
                top: AppSpacing.md,
                child: _RarityTag(rarity: pkg.rarity),
              ),

              // Countdown capsule — top right.
              Positioned(
                right: AppSpacing.md,
                top: AppSpacing.md,
                child: _CountdownCapsule(
                  remaining: pkg.currentHop.remaining(widget.now),
                  accent: palette.fill,
                ),
              ),

              // Package name + peel counter — just above the pedestal.
              Positioned(
                left: 0,
                right: 0,
                bottom: h * 0.30,
                child: Column(
                  children: [
                    Text(
                      '${pkg.regionEmoji} ${pkg.name}',
                      style: const TextStyle(
                        color: AppColors.textOnDark,
                        fontFamily: 'Fraunces',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmt(pkg.peelsAccumulated)} peels · layer ${pkg.layersRevealed}/${pkg.layersTotal}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Holder chip — bottom center, projecting above the pedestal
              // so the user immediately sees who's holding.
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.md,
                child: Center(
                  child: HolderChip(
                    player: widget.holder,
                    isUser: widget.isUser,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '${(n / 1000000).toStringAsFixed(2)}M';
  }
}

class _RarityTag extends StatelessWidget {
  const _RarityTag({required this.rarity});
  final PackageRarity rarity;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.forRarity(rarity.token);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.stroke, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.fill,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            rarity.label.toUpperCase(),
            style: TextStyle(
              color: palette.fill,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownCapsule extends StatelessWidget {
  const _CountdownCapsule({required this.remaining, required this.accent});
  final Duration remaining;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: accent.withOpacity(0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: accent),
          const SizedBox(width: 5),
          LiveCountdown(
            remaining: remaining,
            style: const TextStyle(
              color: AppColors.textOnDark,
              fontFamily: 'Fraunces',
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
