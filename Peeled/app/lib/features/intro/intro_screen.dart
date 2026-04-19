import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/services/intro_service.dart';
import '../../shared/widgets/package_sprite.dart';
import '../../shared/widgets/peel_wordmark.dart';

/// 6-second silent "a package opens" hook.
///
/// Five beats:
///   0.0 – 1.2s  : black; small package fades in, sits at the centre
///   1.2 – 2.6s  : package zooms in, glow swells, dashed ring spins up
///   2.6 – 4.0s  : package gives one big "shake" — a layer flares off
///   4.0 – 5.0s  : wordmark fades in below; "PEELED" reveal
///   5.0 – 6.0s  : tagline "Catch what travels the world." fades in
///
/// Persists `has_seen_intro_v1` once it finishes (or the user taps
/// "Skip") so subsequent launches go straight to /home.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 6000);

  final IntroService _intro = IntroService();
  late final AnimationController _c;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(duration: _total, vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      })
      ..forward();
  }

  Future<void> _finish() async {
    if (_navigated) return;
    _navigated = true;
    await _intro.markIntroSeen();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Helpers — each returns a value clamped to [0..1] across its window.
  double _phase(double startSec, double endSec) {
    final t = _c.value * 6.0;
    if (t <= startSec) return 0;
    if (t >= endSec) return 1;
    return ((t - startSec) / (endSec - startSec)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: GestureDetector(
        // Tap anywhere to skip the intro.
        onTap: _finish,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final fadeIn = _phase(0.0, 1.2);
            final zoom = _phase(1.2, 2.6);
            final shake = _phase(2.6, 4.0);
            final wordmark = _phase(4.0, 5.0);
            final tagline = _phase(5.0, 6.0);

            // Compose the package transform from the three motion beats.
            final scale = 0.7 + 0.4 * Curves.easeOutCubic.transform(zoom);
            final shakeOffset = sin(shake * 2 * pi * 4) * 8 * (1 - shake);

            return Stack(
              fit: StackFit.expand,
              children: [
                // Skip hint, top-right.
                Positioned(
                  top: 36,
                  right: 18,
                  child: Opacity(
                    opacity: 0.45,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Tap to skip',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 16, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),

                // Background pulse glow.
                Center(
                  child: Container(
                    width: 380,
                    height: 380,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.coral.withOpacity(0.35 * (fadeIn + zoom)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // The package itself.
                Center(
                  child: Transform.translate(
                    offset: Offset(shakeOffset, 0),
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: fadeIn,
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: PackageSprite(
                              rarity: shake > 0.6 ? 'legendary' : 'epic',
                              size: 220),
                        ),
                      ),
                    ),
                  ),
                ),

                // A "layer" peeling off — drawn as a thin curved sliver
                // that flies up and to the right during the shake beat.
                if (shake > 0)
                  Center(
                    child: Transform.translate(
                      offset: Offset(80 * shake, -120 * shake),
                      child: Transform.rotate(
                        angle: -0.6 * shake,
                        child: Opacity(
                          opacity: 1 - shake,
                          child: Container(
                            width: 140 * (1 - shake * 0.3),
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.kraft,
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x66000000),
                                    blurRadius: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Wordmark — fades in after the shake.
                Positioned(
                  bottom: 200,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: wordmark,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - wordmark)),
                        child: const PeelWordmark(height: 60, showAccent: true),
                      ),
                    ),
                  ),
                ),

                // Tagline.
                Positioned(
                  bottom: 130,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: tagline,
                      child: const Text(
                        'Catch what travels the world.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),

                // Tiny progress bar along the bottom — purely decorative
                // but tells the user this is a timed intro.
                Positioned(
                  bottom: AppSpacing.md,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: _c.value,
                      minHeight: 3,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.coral),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
