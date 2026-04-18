import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../services/session_store.dart';

class AuthRepository {
  AuthRepository(this._api, this._session);
  final ApiClient _api;
  final SessionStore _session;

  Future<String> login({required String supabaseJwt, String? deviceId}) async {
    final resp = await _api.post('/api/v1/auth/login', body: {
      'supabase_jwt': supabaseJwt,
      if (deviceId != null) 'device_id': deviceId,
    });
    final token = resp['session_token'] as String;
    await _session.writeSessionToken(token);
    return token;
  }

  Future<String> actionToken({
    required String action,
    String? packageId,
  }) async {
    final resp = await _api.post('/api/v1/auth/action-token', body: {
      'action': action,
      if (packageId != null) 'package_id': packageId,
    });
    return resp['token'] as String;
  }

  Future<void> logout() => _session.clearSession();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  ),
);
