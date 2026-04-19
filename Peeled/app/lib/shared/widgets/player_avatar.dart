import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Round avatar. Renders the emoji glyph on top of a rarity-tinted disc.
/// Used in the Home tracker card, feed rows, and leaderboard.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.emoji,
    this.size = 48,
    this.tint,
    this.ring = false,
  });

  final String emoji;
  final double size;
  final Color? tint;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final bg = tint ?? AppColors.surfaceDarkElevated;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: ring
            ? Border.all(color: AppColors.coral, width: 2.5)
            : Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.52),
      ),
    );
  }
}
