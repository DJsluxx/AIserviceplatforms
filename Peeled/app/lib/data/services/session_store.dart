import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';

/// Persists the session token and device id in secure storage.
class SessionStore {
  SessionStore(this._storage);
  final FlutterSecureStorage _storage;

  Future<String?> readSessionToken() =>
      _storage.read(key: AppConstants.kSessionTokenKey);

  Future<void> writeSessionToken(String token) =>
      _storage.write(key: AppConstants.kSessionTokenKey, value: token);

  Future<void> clearSession() =>
      _storage.delete(key: AppConstants.kSessionTokenKey);

  Future<String?> readDeviceId() =>
      _storage.read(key: AppConstants.kDeviceIdKey);

  Future<void> writeDeviceId(String id) =>
      _storage.write(key: AppConstants.kDeviceIdKey, value: id);
}

final sessionStoreProvider = Provider<SessionStore>(
  (_) => SessionStore(const FlutterSecureStorage()),
);
