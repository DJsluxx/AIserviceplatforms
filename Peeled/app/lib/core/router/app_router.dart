import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/intro/intro_screen.dart';
import '../../features/leaderboard/leaderboard_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/opening/opening_screen.dart';
import '../../features/package/peel_screen.dart';
import '../../features/package_detail/package_detail_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shop/shop_screen.dart';
import '../../features/worldmap/worldmap_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final hasSeenIntro = ref.watch(hasSeenIntroProvider);
  return GoRouter(
    initialLocation: hasSeenIntro ? '/home' : '/intro',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(path: '/intro', builder: (_, __) => const IntroScreen()),
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/package/:id',
        builder: (_, state) =>
            PackageDetailScreen(packageId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/peel/:id',
        builder: (_, state) =>
            PeelScreen(packageId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/opening/:id',
        builder: (_, state) =>
            OpeningPackageScreen(packageId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/map',
        // Optional `?focus=<packageId>` query — when present, the
        // Globe pre-focuses that package on first build.
        builder: (_, state) =>
            WorldmapScreen(focusPackageId: state.uri.queryParameters['focus']),
      ),
      GoRoute(
          path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/shop', builder: (_, __) => const ShopScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});
