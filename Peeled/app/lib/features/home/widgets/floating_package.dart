import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/models/game_state.dart';
import '../../../shared/widgets/themed_package.dart';

/// Wraps a [ThemedPackage] in a slow, continuous motion: a vertical
/// sine-bob (≈4 s) and a slow Y-axis spin (≈12 s), plus a subtle tilt
/// that follows the bob. The result reads as a lazily-floating artefact
/// under the beam of light.
///
/// Performance: single [AnimationController] drives both motions, one
/// [RepaintBoundary], one [AnimatedBuilder].
class FloatingPackage extends StatefulWidget {
  const FloatingPackage({
    super.key,
    required this.theme,
    required this.rarity,
    this.size = 200,
    this.bobPeriod = const Duration(seconds: 4),
    this.spinPeriod = const Duration(seconds: 14),
    this.bobAmplitude = 10,
  });

  final PackageTheme theme;
  final PackageRarity rarity;
  final double size;
  final Duration bobPeriod;
  final Duration spinPeriod;
  final double bobAmplitude;

  @override
  State<FloatingPackage> createState() => _FloatingPackageState();
}

class _FloatingPackageState extends State<FloatingPackage>
    with SingleTickerProviderStateMixin {
  // One controller, used as a unit-time source. We compute bob and spin
  // phases from elapsed wallclock time so the two motions are
  // independent but stay in lockstep across rebuilds.
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  )..repeat();

  final _epoch = DateTime.now();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, __) {
          final elapsed = DateTime.now().difference(_epoch).inMilliseconds;
          final bobT =
              (elapsed % widget.bobPeriod.inMilliseconds) /
                  widget.bobPeriod.inMilliseconds;
          final spinT =
              (elapsed % widget.spinPeriod.inMilliseconds) /
                  widget.spinPeriod.inMilliseconds;

          final bobY = sin(bobT * 2 * pi) * widget.bobAmplitude;
          final tilt = sin(bobT * 2 * pi) * 0.04; // slight roll as it bobs
          final yaw = spinT * 2 * pi;

          // Subtle perspective — Matrix4.setEntry(3, 2, …).
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..translate(0.0, bobY)
            ..rotateX(tilt)
            ..rotateY(yaw);

          return Transform(
            transform: m,
            alignment: Alignment.center,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: ThemedPackage(
                theme: widget.theme,
                rarity: widget.rarity,
                size: widget.size,
              ),
            ),
          );
        },
      ),
    );
  }
}
