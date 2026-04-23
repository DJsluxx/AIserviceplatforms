import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/player.dart';
import '../../../shared/widgets/player_avatar.dart';

/// Floating glass pill under the hero stage that shows who currently
/// HOLDS this package: avatar, @handle, city + flag, and a "holding"
/// micro-label. Uses the player's real avatar photo when available.
class HolderChip extends StatelessWidget {
  const HolderChip({
    super.key,
    required this.player,
    required this.isUser,
  });

  final Player player;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: isUser
              ? AppColors.coral.withOpacity(0.7)
              : Colors.white.withOpacity(0.14),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerAvatar(
            emoji: player.avatarEmoji,
            imageUrl: player.avatarUrl,
            size: 36,
            ring: isUser,
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isUser ? 'Holding' : 'Holding now',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isUser ? '@you' : _handleFor(player),
                style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${player.city} ${player.flag}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Derives an `@handle` from the player's display name. The AI roster
  /// only carries `name` right now — mash it to a compact handle.
  String _handleFor(Player p) {
    final raw = p.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (raw.isEmpty) return '@player';
    return '@$raw';
  }
}
