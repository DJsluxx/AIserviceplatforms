import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Pill showing current coin balance. Plays a quick shake + shimmer on
/// each value change — that tiny feedback loop is the whole "juice" of
/// the reward cycle.
class CoinBalance extends StatelessWidget {
  const CoinBalance({super.key, required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.ink.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.gold.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            _formatInt(coins),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ).animate(key: ValueKey(coins)).shimmer(
                duration: 500.ms,
                color: Colors.white.withOpacity(0.4),
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
