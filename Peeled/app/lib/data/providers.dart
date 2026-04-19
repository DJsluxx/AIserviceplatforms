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
