import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/game_simulator.dart';

/// Shared singleton [GameSimulator]. Disposed when the ProviderScope dies.
final gameSimulatorProvider = Provider<GameSimulator>((ref) {
  final sim = GameSimulator();
  ref.onDispose(sim.dispose);
  return sim;
});

/// Widgets listen to this; it re-emits on every tick / state mutation.
final gameStateProvider = ChangeNotifierProvider<GameSimulator>((ref) {
  return ref.watch(gameSimulatorProvider);
});

/// Whether the 6-second intro animation has been shown previously on
/// this device. Resolved at startup in main.dart and overridden into
/// the ProviderScope so the router can branch synchronously.
final hasSeenIntroProvider = Provider<bool>((ref) {
  throw UnimplementedError(
      'hasSeenIntroProvider must be overridden in main()');
});
