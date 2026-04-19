import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/providers.dart';
import '../../shared/widgets/juicy_button.dart';
import '../../shared/widgets/peel_wordmark.dart';

const List<String> _handleWords = [
  'Comet', 'Ember', 'Wisp', 'Lark', 'Fox',
  'Oak', 'Rune', 'Finch', 'Tide', 'Clove',
  'Moss', 'Saga', 'Aria', 'Bolt', 'Dusk',
];

const List<String> _avatarPool = ['🦊', '🌙', '🔥', '🌊', '🍀', '💎', '⚡', '❄️', '🦄'];

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: PeelWordmark(height: 64))
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: -0.1, end: 0),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'The global viral game where\npackages travel the world.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
              const Spacer(),
              JuicyButton(
                label: 'Continue with Apple',
                icon: Icons.apple,
                primary: Colors.white,
                shadow: const Color(0xFFAAAAAA),
                onPressed: () => _enter(ref, context),
              ),
              const SizedBox(height: AppSpacing.md),
              JuicyButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata,
                primary: AppColors.ink,
                onPressed: () => _enter(ref, context),
              ),
              const SizedBox(height: AppSpacing.md),
              JuicyButton(
                label: 'Play as Guest',
                primary: AppColors.kraft,
                onPressed: () => _enter(ref, context),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'By continuing you accept our Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  void _enter(WidgetRef ref, BuildContext ctx) {
    // Assign a friendly random handle and avatar so the player has something
    // to show on Profile/Leaderboard right away.
    final r = Random();
    final handle = '${_handleWords[r.nextInt(_handleWords.length)]}'
        '${100 + r.nextInt(900)}';
    final avatar = _avatarPool[r.nextInt(_avatarPool.length)];
    ref.read(gameSimulatorProvider).setUserProfile(
          handle: handle.toLowerCase(),
          avatar: avatar,
        );
    ctx.go('/home');
  }
}
