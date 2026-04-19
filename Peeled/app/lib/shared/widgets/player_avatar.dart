import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Round avatar. Renders a real portrait photo from [avatarUrl] when
/// available; falls back to the emoji glyph while the photo loads (or
/// permanently if we're offline). Used in the Home tracker card, feed
/// rows, profile, and leaderboard.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.emoji,
    this.imageUrl,
    this.size = 48,
    this.tint,
    this.ring = false,
  });

  final String emoji;
  final String? imageUrl;
  final double size;
  final Color? tint;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final bg = tint ?? AppColors.surfaceDarkElevated;
    final border = ring
        ? Border.all(color: AppColors.coral, width: 2.5)
        : Border.all(color: Colors.white.withOpacity(0.08));

    Widget child;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      child = ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Show the emoji while loading so the row never looks empty.
          loadingBuilder: (context, w, progress) {
            if (progress == null) return w;
            return _emojiTile(bg);
          },
          errorBuilder: (context, error, stack) => _emojiTile(bg),
          gaplessPlayback: true,
        ),
      );
    } else {
      child = _emojiTile(bg);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: border,
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _emojiTile(Color bg) {
    return Container(
      width: size,
      height: size,
      color: bg,
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.52),
      ),
    );
  }
}
