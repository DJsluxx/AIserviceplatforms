import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/juicy_button.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              SvgPicture.asset('assets/svg/logo/wordmark.svg', height: 56),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "Sign in to start peeling",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const Spacer(),
              JuicyButton(
                label: "Continue with Apple",
                icon: Icons.apple,
                primary: Colors.white,
                shadow: const Color(0xFFAAAAAA),
                onPressed: () => _handle(context),
              ),
              const SizedBox(height: AppSpacing.md),
              JuicyButton(
                label: "Continue with Google",
                icon: Icons.g_mobiledata,
                primary: AppColors.ink,
                onPressed: () => _handle(context),
              ),
              const SizedBox(height: AppSpacing.md),
              JuicyButton(
                label: "Play as Guest",
                primary: AppColors.kraft,
                onPressed: () => _handle(context),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  void _handle(BuildContext ctx) {
    ctx.go('/home');
  }
}
