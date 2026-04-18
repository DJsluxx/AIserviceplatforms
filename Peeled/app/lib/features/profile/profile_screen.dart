import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/juicy_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.coral,
              child: const Icon(Icons.person, size: 48, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('@you', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            const Text('Level 5 · 12-day streak 🔥'),
            const Spacer(),
            JuicyButton(
              label: 'Sign out',
              primary: AppColors.kraft,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
