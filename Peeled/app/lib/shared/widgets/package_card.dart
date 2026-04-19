import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/game_state.dart';
import '../../data/models/player.dart';
import 'live_countdown.dart';
import 'mini_globe.dart';
import 'player_avatar.dart';
import 'themed_package.dart';

/// A single package on the Home feed. Self-contained: shows region
/// badge, themed hero art, climbing peels-accumulated counter, layer
/// pips, a mini-globe trail of the last ~5 cities, current holder
/// strip, and a "PEEL NOW" CTA if it's the user's turn.
class PackageCard extends StatelessWidget {
  const PackageCard({
    super.key,
    required this.package,
    required this.holder,
    required this.previousHolder,
    required this.recentHolders,
    required this.now,
    required this.isYours,
  });

  final Package package;
  final Player holder;
  final Player? previousHolder;
  final List<Player> recentHolders;
  final DateTime now;
  final bool isYours;

  @override
  Widget build(BuildContext context) {
    final palette = paletteForPackage(package.theme, package.rarity);
    final hop = package.currentHop;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceDarkElevated,
            AppColors.surfaceDarkElevated.withOpacity(0.7),
          ],
        ),
        border: Border.all(
            color: isYours ? palette.fill : Colors.white.withOpacity(0.05),
            width: isYours ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: palette.glow.withOpacity(isYours ? 0.7 : 0.25),
            blurRadius: isYours ? 32 : 16,
            spreadRadius: isYours ? 1 : -2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderRow(package: package),
            const SizedBox(height: AppSpacing.sm),
            _Hero(package: package, palette: palette),
            const SizedBox(height: AppSpacing.sm),
            _PeelsCounter(count: package.peelsAccumulated, color: palette.fill),
            const SizedBox(height: AppSpacing.sm),
            _LayersPips(
              revealed: package.layersRevealed,
              total: package.layersTotal,
              color: palette.fill,
            ),
            const SizedBox(height: AppSpacing.md),
            MiniGlobe(package: package, holders: recentHolders),
            const SizedBox(height: AppSpacing.sm),
            _HolderRow(
              holder: holder,
              previous: previousHolder,
              remaining: hop.remaining(now),
              isYours: isYours,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (isYours && !hop.peelAttempted)
              _PeelCta(packageId: package.id, color: palette.fill)
            else
              _OutcomeStrip(hop: hop, isYours: isYours),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.package});
  final Package package;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.ink.withOpacity(0.7),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(package.regionEmoji,
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                package.regionLabel.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            package.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontFamily: 'Fraunces',
              fontSize: 14,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.package, required this.palette});
  final Package package;
  final RarityPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [palette.glow, Colors.transparent],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.08, 1.08),
                duration: 2000.ms,
                curve: Curves.easeInOut,
              ),
          SizedBox(
            width: 200,
            height: 200,
            child: ThemedPackage(
              theme: package.theme,
              rarity: package.rarity,
              size: 200,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -5,
                end: 5,
                duration: 2400.ms,
                curve: Curves.easeInOut,
              ),
        ],
      ),
    );
  }
}

/// Climbing "50,237" counter. TweenAnimationBuilder + ShaderMask gives
/// an odometer-style roll + gradient shimmer on every increment.
class _PeelsCounter extends StatelessWidget {
  const _PeelsCounter({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'TOTAL PEELS',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 2),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: count.toDouble()),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => ShaderMask(
            shaderCallback: (r) => LinearGradient(
              colors: [color, Colors.white, color],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(r),
            blendMode: BlendMode.srcIn,
            child: Text(
              _formatInt(v.toInt()),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Fraunces',
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                height: 1.0,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'and counting worldwide',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _LayersPips extends StatelessWidget {
  const _LayersPips(
      {required this.revealed, required this.total, required this.color});
  final int revealed;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (total > 14) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.layers_outlined,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            '$revealed revealed',
            style: const TextStyle(
              color: AppColors.textOnDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            ' / ??? total',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final on = i < revealed;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? color : Colors.white.withOpacity(0.12),
            border: Border.all(
              color: on ? color : Colors.white.withOpacity(0.2),
            ),
          ),
        );
      }),
    );
  }
}

class _HolderRow extends StatelessWidget {
  const _HolderRow({
    required this.holder,
    required this.previous,
    required this.remaining,
    required this.isYours,
  });
  final Player holder;
  final Player? previous;
  final Duration remaining;
  final bool isYours;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PlayerAvatar(
          emoji: holder.avatarEmoji,
          imageUrl: holder.avatarUrl,
          size: 38,
          ring: isYours,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                      color: AppColors.textOnDark, fontSize: 13),
                  children: [
                    const TextSpan(
                      text: 'With ',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    TextSpan(
                      text: isYours ? 'you' : holder.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(
                      text: ' in ${holder.city} ${holder.flag}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (previous != null)
                Text(
                  'from ${previous!.city} ${previous!.flag}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
            ],
          ),
        ),
        LiveCountdown(
          remaining: remaining,
          style: const TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PeelCta extends StatelessWidget {
  const _PeelCta({required this.packageId, required this.color});
  final String packageId;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => context.push('/peel/$packageId'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'PEEL NOW — ONE SHOT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.02,
          duration: 700.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _OutcomeStrip extends StatelessWidget {
  const _OutcomeStrip({required this.hop, required this.isYours});
  final PackageHop hop;
  final bool isYours;

  @override
  Widget build(BuildContext context) {
    if (!hop.peelAttempted) {
      return Container(
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: AppColors.surfaceDark.withOpacity(0.6),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_bottom_rounded,
                size: 16, color: AppColors.textMuted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Waiting for the peel attempt…',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    final hit = hop.outcome == PeelOutcome.hit;
    final bg = hit
        ? AppColors.mint.withOpacity(0.12)
        : AppColors.textMuted.withOpacity(0.08);
    final border = hit ? AppColors.mint : AppColors.textMuted;
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(hit ? '✨' : '🍃', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hit
                  ? (isYours ? 'You peeled a layer!' : 'A layer was revealed')
                  : (isYours ? 'No layer this time.' : 'Peel missed'),
              style: const TextStyle(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
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
