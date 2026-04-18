import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/package_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/package_repository.dart';

typedef PeelResult = ({
  PackageModel package,
  PeeledLayerModel revealed,
  bool isFinal,
  Map<String, dynamic>? reward,
});

class PeelController extends StateNotifier<AsyncValue<PackageModel?>> {
  PeelController(this._auth, this._repo) : super(const AsyncValue.loading());

  final AuthRepository _auth;
  final PackageRepository _repo;

  Future<PeelResult> peel(String packageId) async {
    final token = await _auth.actionToken(action: 'peel', packageId: packageId);
    final result = await _repo.peel(packageId, actionToken: token);
    state = AsyncValue.data(result.package);
    return result;
  }

  Future<void> pass(String packageId) async {
    final token = await _auth.actionToken(action: 'pass', packageId: packageId);
    final pkg = await _repo.pass(packageId, actionToken: token);
    state = AsyncValue.data(pkg);
  }
}

final peelControllerProvider =
    StateNotifierProvider<PeelController, AsyncValue<PackageModel?>>((ref) {
  return PeelController(
    ref.watch(authRepositoryProvider),
    ref.watch(packageRepositoryProvider),
  );
});
