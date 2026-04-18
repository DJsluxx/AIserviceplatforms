import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/leaderboard/leaderboard_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/package/peel_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shop/shop_screen.dart';
import '../../features/worldmap/worldmap_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/peel/:id',
        builder: (_, state) => PeelScreen(packageId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/map', builder: (_, __) => const WorldmapScreen()),
      GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/shop', builder: (_, __) => const ShopScreen()),
    ],
  );
});
