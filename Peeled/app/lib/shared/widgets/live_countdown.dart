import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Formats a [Duration] as `MM:SS` (under an hour) or `Hh MMm` (above).
String formatDuration(Duration d) {
  if (d.inHours >= 1) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${h}h ${m}m';
  }
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// A small, pulsing countdown readout. Colour shifts to danger under 15s.
class LiveCountdown extends StatelessWidget {
  const LiveCountdown({
    super.key,
    required this.remaining,
    this.style,
  });

  final Duration remaining;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final danger = remaining.inSeconds <= 15;
    final base = style ??
        const TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 22,
          fontWeight: FontWeight.w700,
        );
    return Text(
      formatDuration(remaining),
      style: base.copyWith(
        color: danger ? AppColors.danger : AppColors.textOnDark,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
