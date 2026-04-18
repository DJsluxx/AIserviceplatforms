import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/package_model.dart';

class PackageRepository {
  PackageRepository(this._api);
  final ApiClient _api;

  Future<InboxModel> inbox() async {
    final resp = await _api.get('/api/v1/packages/inbox');
    return InboxModel.fromJson(resp['data'] as Map<String, dynamic>);
  }

  Future<({PackageModel package, PeeledLayerModel revealed, bool isFinal,
      Map<String, dynamic>? reward})> peel(
    String packageId, {
    required String actionToken,
    String? deviceId,
  }) async {
    final resp = await _api.post(
      '/api/v1/packages/$packageId/peel',
      body: {
        'action_token': actionToken,
        if (deviceId != null) 'device_id': deviceId,
      },
    );
    final data = resp['data'] as Map<String, dynamic>;
    return (
      package: PackageModel.fromJson(data['package'] as Map<String, dynamic>),
      revealed: PeeledLayerModel.fromJson(data['revealed'] as Map<String, dynamic>),
      isFinal: data['is_final'] as bool,
      reward: data['reward'] as Map<String, dynamic>?,
    );
  }

  Future<PackageModel> pass(String packageId, {required String actionToken}) async {
    final resp = await _api.post(
      '/api/v1/packages/$packageId/pass',
      body: {'action_token': actionToken},
    );
    return PackageModel.fromJson(resp['data'] as Map<String, dynamic>);
  }

  Future<PackageModel> sendToFriend(
    String packageId, {
    required String friendUserId,
    required String actionToken,
  }) async {
    final resp = await _api.post(
      '/api/v1/packages/$packageId/send-to-friend',
      body: {'action_token': actionToken, 'friend_user_id': friendUserId},
    );
    return PackageModel.fromJson(resp['data'] as Map<String, dynamic>);
  }

  Future<PackageModel> create({
    required String actionToken,
    String? theme,
    int? layerCount,
  }) async {
    final resp = await _api.post(
      '/api/v1/packages/create',
      body: {
        'action_token': actionToken,
        if (theme != null) 'theme': theme,
        if (layerCount != null) 'layer_count': layerCount,
      },
    );
    return PackageModel.fromJson(resp['data'] as Map<String, dynamic>);
  }
}

final packageRepositoryProvider = Provider<PackageRepository>(
  (ref) => PackageRepository(ref.watch(apiClientProvider)),
);
