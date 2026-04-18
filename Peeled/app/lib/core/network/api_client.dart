import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../../data/services/session_store.dart';

/// Typed API client with auth header injection and consistent error parsing.
class ApiClient {
  ApiClient(this._dio, this._session);

  final Dio _dio;
  final SessionStore _session;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body,
      Map<String, dynamic>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) =>
      _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final token = await _session.readSessionToken();
    try {
      final resp = await _dio.request<Map<String, dynamic>>(
        path,
        queryParameters: query,
        data: body,
        options: Options(
          method: method,
          headers: {
            if (token != null) 'authorization': 'Bearer $token',
            'content-type': 'application/json',
            'x-peeled-client': 'flutter/${kReleaseMode ? 'rel' : 'dev'}',
          },
        ),
      );
      return resp.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      final code = e.response?.data is Map
          ? (e.response!.data['error']?['code'] ?? 'NETWORK_ERROR')
          : 'NETWORK_ERROR';
      final msg = e.response?.data is Map
          ? (e.response!.data['error']?['message'] ?? e.message ?? 'Network error')
          : (e.message ?? 'Network error');
      throw ApiException(code: code.toString(), message: msg.toString(),
          status: e.response?.statusCode ?? 0);
    }
  }
}

class ApiException implements Exception {
  ApiException({required this.code, required this.message, required this.status});
  final String code;
  final String message;
  final int status;

  @override
  String toString() => 'ApiException($status $code): $message';
}

final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment(
      'SERVER_BASE_URL',
      defaultValue: AppConstants.defaultServerBaseUrl,
    ),
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    validateStatus: (s) => s != null && s < 500,
  ));
  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(_dioProvider);
  final session = ref.watch(sessionStoreProvider);
  return ApiClient(dio, session);
});
