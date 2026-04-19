import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'data/services/intro_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Resolve the "have we shown the intro yet?" flag before starting the
  // router so we can skip /intro on subsequent launches without a
  // visible flash of the wrong route.
  final hasSeenIntro = await IntroService().hasSeenIntro();
  runApp(ProviderScope(
    overrides: [
      hasSeenIntroProvider.overrideWithValue(hasSeenIntro),
    ],
    child: const PeeledApp(),
  ));
}

class PeeledApp extends ConsumerStatefulWidget {
  const PeeledApp({super.key});

  @override
  ConsumerState<PeeledApp> createState() => _PeeledAppState();
}

class _PeeledAppState extends ConsumerState<PeeledApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Boot the simulator (which boots SoundService + NotificationService).
    // Reading via `ref.read` so we kick the lazy provider — no listener.
    Future<void>.microtask(() async {
      final sim = ref.read(gameSimulatorProvider);
      await sim.notifications.init();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final sim = ref.read(gameSimulatorProvider);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        sim.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        sim.onAppResumed();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'PEELED',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
