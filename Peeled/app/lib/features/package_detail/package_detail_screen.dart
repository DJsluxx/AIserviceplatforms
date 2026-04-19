import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/game_state.dart';
import '../../data/models/player.dart';
import '../../data/providers.dart';
import '../../data/services/game_simulator.dart';
import '../../shared/widgets/coin_balance.dart';
import '../../shared/widgets/juicy_button.dart';
import '../../shared/widgets/live_countdown.dart';
import '../../shared/widgets/mini_globe.dart';
import '../../shared/widgets/player_avatar.dart';
import '../../shared/widgets/themed_package.dart';

/// Detail / metadata view for a single package. Opened by tapping the
/// hero card on Home (the PEEL CTA still bypasses this and goes
/// straight to /peel). Mirrors the home card's content but with much
/// more information surfaced and clear actions:
///
///   • themed hero art + glow
///   • live "TOTAL PEELS" odometer + "and counting worldwide" line
///   • metadata grid (rarity, layers, hops, region, time-window)
///   • current holder + previous-city strip + 5-minute countdown
///   • inline mini-globe trail of last 5 cities
///   • PEEL NOW CTA when the package is in the user's hands
///   • "View on Globe" button → /map?focus=<id>
///   • recent peel attempts list + revealed hints
class PackageDetailScreen extends ConsumerWidget {
  const PackageDetailScreen({super.key, required this.packageId});
  final String packageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sim = ref.watch(gameStateProvider);
    final s = sim.state;
    final pkg = s.packageById(packageId);

    if (pkg == null) {
      // Package was opened + respawned with a new id — bounce home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go('/home');
      });
      return const Scaffold(
        backgroundColor: AppColors.surfaceDark,
        body: SizedBox.shrink(),
      );
    }

    final palette = paletteForPackage(pkg.theme, pkg.rarity);
    final holder = s.holderOf(pkg);
    final previous = s.previousHolderOf(pkg);
    final hop = pkg.currentHop;
    final isYours = hop.holderId == s.user.id && !pkg.opened;

    // Recent holders (oldest → newest, last 5) for the mini-globe.
    final hops = pkg.hops;
    final tail = hops.length <= 5 ? hops : hops.sublist(hops.length - 5);
    final recentHolders = [
      for (final h in tail)
        h.holderId == s.user.id
            ? _userPlayerFor(s)
            : AiPlayers.byId(h.holderId)
    ];

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pkg.regionEmoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                pkg.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: CoinBalance(coins: s.user.coins),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxl),
        children: [
          _RegionRow(pkg: pkg),
          const SizedBox(height: AppSpacing.sm),
          _Hero(pkg: pkg, palette: palette),
          const SizedBox(height: AppSpacing.sm),
          _PeelsCounter(count: pkg.peelsAccumulated, color: palette.fill),
          const SizedBox(height: AppSpacing.lg),
          _HolderStrip(
            holder: holder,
            previous: previous,
            remaining: hop.remaining(s.now),
            isYours: isYours,
          ),
          const SizedBox(height: AppSpacing.md),
          if (isYours && !hop.peelAttempted)
            _PeelCta(packageId: pkg.id, color: palette.fill)
          else if (hop.peelAttempted)
            _OutcomeBanner(hop: hop, isYours: isYours)
          else
            _WaitingStrip(holderName: holder.name),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle('Live location'),
          const SizedBox(height: AppSpacing.xs),
          MiniGlobe(package: pkg, holders: recentHolders, height: 180),
          const SizedBox(height: AppSpacing.xs),
          _GlobeAction(packageId: pkg.id, regionLabel: pkg.regionLabel),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle('Metadata'),
          const SizedBox(height: AppSpacing.xs),
          _MetadataGrid(pkg: pkg, totalHops: pkg.hops.length),
          if (pkg.hints.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _SectionTitle('Hints revealed (${pkg.hints.length})'),
            const SizedBox(height: AppSpacing.xs),
            for (int i = pkg.hints.length - 1;
                i >= (pkg.hints.length - 5).clamp(0, pkg.hints.length);
                i--)
              _HintRow(hint: pkg.hints[i], idx: i),
          ],
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle('Recent attempts'),
          const SizedBox(height: AppSpacing.xs),
          ..._recentAttempts(pkg, s),
        ],
      ),
    );
  }

  List<Widget> _recentAttempts(Package pkg, GameState s) {
    final attempts = pkg.hops
        .where((h) => h.peelAttempted)
        .toList()
        .reversed
        .take(5)
        .toList();
    if (attempts.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: Text('No peel attempts yet — be the first.',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      ];
    }
    return [
      for (final h in attempts)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _AttemptRow(hop: h, state: s),
        ),
    ];
  }
}

Player _userPlayerFor(GameState s) => Player(
      id: s.user.id,
      name: 'You',
      avatarEmoji: s.user.avatarEmoji,
      avatarUrl: s.user.avatarUrl,
      city: s.user.city,
      country: '',
      flag: s.user.flag,
      lat: 0,
      lon: 0,
      isUser: true,
    );

class _RegionRow extends StatelessWidget {
  const _RegionRow({required this.pkg});
  final Package pkg;

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
              Text(pkg.regionEmoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                pkg.regionLabel.toUpperCase(),
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
        Text(
          pkg.scope == PackageScope.global ? 'WORLD CHANNEL' : 'REGIONAL DROP',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.pkg, required this.palette});
  final Package pkg;
  final RarityPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 320,
            height: 320,
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
            width: 220,
            height: 220,
            child: ThemedPackage(
              theme: pkg.theme,
              rarity: pkg.rarity,
              size: 220,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -6,
                end: 6,
                duration: 2400.ms,
                curve: Curves.easeInOut,
              ),
        ],
      ),
    );
  }
}

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
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                height: 1.0,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
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

class _HolderStrip extends StatelessWidget {
  const _HolderStrip({
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDarkElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: isYours ? AppColors.coral : Colors.white.withOpacity(0.05),
            width: isYours ? 2 : 1),
      ),
      child: Row(
        children: [
          PlayerAvatar(
            emoji: holder.avatarEmoji,
            imageUrl: holder.avatarUrl,
            size: 52,
            ring: isYours,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'IN THE HANDS OF',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isYours ? 'You' : holder.name,
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontFamily: 'Fraunces',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${holder.city} ${holder.flag}',
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                if (previous != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'from ${previous!.city} ${previous!.flag}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'WINDOW',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              LiveCountdown(
                remaining: remaining,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'of 5:00',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaitingStrip extends StatelessWidget {
  const _WaitingStrip({required this.holderName});
  final String holderName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: AppColors.surfaceDarkElevated.withOpacity(0.6),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom_rounded,
              color: AppColors.textMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Waiting for $holderName to take their shot…",
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeBanner extends StatelessWidget {
  const _OutcomeBanner({required this.hop, required this.isYours});
  final PackageHop hop;
  final bool isYours;

  @override
  Widget build(BuildContext context) {
    final hit = hop.outcome == PeelOutcome.hit;
    final bg = hit
        ? AppColors.mint.withOpacity(0.15)
        : AppColors.textMuted.withOpacity(0.1);
    final border = hit ? AppColors.mint : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(hit ? '✨' : '🍃', style: const TextStyle(fontSize: 26)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              hit
                  ? (isYours ? 'You peeled a layer!' : 'A layer was revealed.')
                  : (isYours ? 'No layer this time.' : 'Peel missed.'),
              style: const TextStyle(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeelCta extends StatelessWidget {
  const _PeelCta({required this.packageId, required this.color});
  final String packageId;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return JuicyButton(
      label: 'PEEL NOW — ONE SHOT',
      icon: Icons.touch_app_rounded,
      primary: color,
      onPressed: () => context.push('/peel/$packageId'),
    );
  }
}

class _GlobeAction extends StatelessWidget {
  const _GlobeAction({required this.packageId, required this.regionLabel});
  final String packageId;
  final String regionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          icon: const Icon(Icons.public_rounded, color: AppColors.coral),
          onPressed: () => context.go('/map?focus=$packageId'),
          label: Text(
            'View on Globe — $regionLabel',
            style: const TextStyle(
              color: AppColors.coral,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: AppColors.textOnDark,
          fontFamily: 'Fraunces',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _MetadataGrid extends StatelessWidget {
  const _MetadataGrid({required this.pkg, required this.totalHops});
  final Package pkg;
  final int totalHops;

  @override
  Widget build(BuildContext context) {
    final palette = paletteForPackage(pkg.theme, pkg.rarity);
    final tiles = <_MetaTile>[
      _MetaTile(
          label: 'Rarity',
          value: pkg.rarity.label,
          accent: palette.fill,
          icon: '✨'),
      _MetaTile(
          label: 'Layers revealed',
          value: '${pkg.layersRevealed}',
          accent: AppColors.mint,
          icon: '🧅'),
      _MetaTile(
          label: 'Layers total',
          value: pkg.layersTotal > 14 ? '???' : '${pkg.layersTotal}',
          accent: AppColors.violet,
          icon: '🎁'),
      _MetaTile(
          label: 'Hops so far',
          value: '$totalHops',
          accent: AppColors.coral,
          icon: '🌐'),
      _MetaTile(
          label: 'Region',
          value: '${pkg.regionEmoji} ${pkg.regionLabel}',
          accent: AppColors.kraft,
          icon: '📍'),
      _MetaTile(
          label: 'Window',
          value: '5:00',
          accent: AppColors.gold,
          icon: '⏱'),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.4,
      children: tiles
          .map((t) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDarkElevated,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: t.accent.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(t.icon, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          t.label.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textOnDark,
                        fontFamily: 'Fraunces',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _MetaTile {
  const _MetaTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });
  final String label;
  final String value;
  final Color accent;
  final String icon;
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.hint, required this.idx});
  final String hint;
  final int idx;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${idx + 1}.',
            style: const TextStyle(
              color: AppColors.mint,
              fontFamily: 'Fraunces',
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: const TextStyle(
                color: AppColors.textOnDark,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.hop, required this.state});
  final PackageHop hop;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final p = hop.holderId == state.user.id
        ? _userPlayerFor(state)
        : AiPlayers.byId(hop.holderId);
    final hit = hop.outcome == PeelOutcome.hit;
    return Row(
      children: [
        PlayerAvatar(
          emoji: p.avatarEmoji,
          imageUrl: p.avatarUrl,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                  color: AppColors.textOnDark, fontSize: 13),
              children: [
                TextSpan(
                  text: '${p.name} ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: hit ? 'peeled in ' : 'missed in ',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                TextSpan(text: '${p.city} ${p.flag}'),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Text(hit ? '✨' : '🍃', style: const TextStyle(fontSize: 14)),
      ],
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
