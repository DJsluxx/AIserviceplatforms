import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/package_model.dart';
import '../../shared/widgets/juicy_button.dart';
import '../../shared/widgets/package_card.dart';
import 'home_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(homeInboxProvider);

    return Scaffold(
      appBar: _HomeAppBar(),
      bottomNavigationBar: _BottomNav(current: 0),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homeInboxProvider.future),
        child: inbox.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(message: e.toString()),
          data: (inboxModel) => _InboxList(model: inboxModel),
        ),
      ),
    );
  }
}

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            SvgPicture.asset('assets/svg/logo/wordmark.svg', height: 28),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.bolt_rounded, color: AppColors.gold),
              onPressed: () => context.go('/shop'),
            ),
            IconButton(
              icon: const Icon(Icons.leaderboard_rounded),
              onPressed: () => context.go('/leaderboard'),
            ),
            IconButton(
              icon: const Icon(Icons.person_rounded),
              onPressed: () => context.go('/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({required this.model});
  final InboxModel model;

  @override
  Widget build(BuildContext context) {
    if (model.items.isEmpty) {
      return const _EmptyInbox();
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: model.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) {
        final item = model.items[i];
        return PackageCard(
          item: item,
          onTap: () => _goToPeel(item.package.id),
        );
      },
    );
  }

  void _goToPeel(String id) {
    // using go_router from an imperative context:
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: Text(
            "No packages yet",
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            "Watch the map or send a package to a friend to get the conveyor going.",
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        JuicyButton(
          label: "See the Live Globe",
          icon: Icons.public,
          primary: AppColors.coral,
          onPressed: () => context.go('/map'),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Couldn't reach the server",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: current,
      backgroundColor: AppColors.surfaceDarkElevated,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
        NavigationDestination(icon: Icon(Icons.public), label: 'Globe'),
        NavigationDestination(icon: Icon(Icons.group_outlined), label: 'Friends'),
      ],
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/map');
            break;
          case 2:
            context.go('/profile');
            break;
        }
      },
    );
  }
}
