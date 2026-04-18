import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/juicy_button.dart';
import '../../shared/widgets/package_sprite.dart';
import '../../shared/widgets/peel_wordmark.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  final _slides = const [
    _Slide(
      title: "Mystery packages\ntravel the world",
      body: "Every package starts somewhere. It could land in your hands next.",
      rarity: "epic",
    ),
    _Slide(
      title: "Peel one layer.\nMiss, and it's gone.",
      body: "You get 38 seconds to peel before the package ships onward.",
      rarity: "legendary",
    ),
    _Slide(
      title: "Open the final layer\nand claim the prize.",
      body: "Gold, cosmetics, real-world rewards — wrapped in the rarest ones.",
      rarity: "mythic",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg),
              child: PeelWordmark(height: 44),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlideView(_slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: AppDurations.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.coral : AppColors.coral.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: JuicyButton(
                label: _page == _slides.length - 1 ? "Start Peeling" : "Next",
                primary: AppColors.coral,
                onPressed: () {
                  if (_page == _slides.length - 1) {
                    context.go('/login');
                  } else {
                    _pc.nextPage(
                        duration: AppDurations.medium, curve: Curves.easeOutCubic);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({required this.title, required this.body, required this.rarity});
  final String title;
  final String body;
  final String rarity;
}

class _SlideView extends StatelessWidget {
  const _SlideView(this.s);
  final _Slide s;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PackageSprite(rarity: s.rarity, size: 220),
          const SizedBox(height: AppSpacing.xl),
          Text(
            s.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            s.body,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
