import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, [this.details]);
  final int status;
  final String code;
  final String message;
  final Object? details;
  @override
  String toString() => 'ApiException($status $code: $message)';
}

/// Access + refresh tokens in the platform keystore (Keychain / Android Keystore), never in plain preferences.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  String? _access;
  String? _refresh;

  Future<void> load() async {
    _access = await _s.read(key: 'lt_access');
    _refresh = await _s.read(key: 'lt_refresh');
  }

  String? get access => _access;
  String? get refresh => _refresh;
  bool get hasSession => _refresh != null;

  Future<void> save(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    await _s.write(key: 'lt_access', value: access);
    await _s.write(key: 'lt_refresh', value: refresh);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    await _s.delete(key: 'lt_access');
    await _s.delete(key: 'lt_refresh');
  }
}

/// API client for `/api/v1`. Bearer auth (mobile clients are exempt from CSRF); a 401 triggers one token refresh
/// (refresh tokens rotate) and a single retry. Errors become [ApiException] with the API's error code.
class Api {
  Api(this.tokens, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'accept': 'application/json'},
            ));

  final TokenStore tokens;
  final Dio _dio;
  Completer<bool>? _refreshing;

  /// Called when the session can no longer be refreshed (the app signs the user out).
  void Function()? onSessionExpired;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) => _send<T>('GET', path, query: query);
  Future<T> post<T>(String path, {Object? body, String? idempotencyKey}) => _send<T>('POST', path, body: body, idempotencyKey: idempotencyKey);
  Future<T> patch<T>(String path, {Object? body}) => _send<T>('PATCH', path, body: body);
  Future<T> delete<T>(String path) => _send<T>('DELETE', path);

  Future<T> _send<T>(String method, String path, {Map<String, dynamic>? query, Object? body, String? idempotencyKey, bool retried = false}) async {
    final headers = <String, String>{};
    if (tokens.access != null) headers['authorization'] = 'Bearer ${tokens.access}';
    if (idempotencyKey != null) headers['idempotency-key'] = idempotencyKey;
    try {
      final r = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query?..removeWhere((_, v) => v == null),
        options: Options(method: method, headers: headers),
      );
      return r.data as T;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401 && !retried && tokens.hasSession && !path.startsWith('/api/v1/auth/')) {
        if (await _refresh()) return _send<T>(method, path, query: query, body: body, idempotencyKey: idempotencyKey, retried: true);
      }
      throw _toException(e);
    }
  }

  Future<bool> _refresh() async {
    if (_refreshing != null) return _refreshing!.future;
    final c = _refreshing = Completer<bool>();
    try {
      final r = await _dio.post<Map<String, dynamic>>('/api/v1/auth/refresh', data: {'refreshToken': tokens.refresh, 'client': 'mobile'});
      await tokens.save(r.data!['accessToken'] as String, r.data!['refreshToken'] as String);
      c.complete(true);
    } on DioException catch (e) {
      // Only a rejected refresh token ends the session. Offline, timeouts or rate limiting (429) keep it so the
      // next request can refresh again instead of signing the user out.
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await tokens.clear();
        onSessionExpired?.call();
      }
      c.complete(false);
    } catch (_) {
      c.complete(false);
    } finally {
      _refreshing = null;
    }
    return c.future;
  }

  ApiException _toException(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(e.response!.statusCode ?? 0, '${err['code'] ?? 'HTTP_ERROR'}', '${err['message'] ?? ''}', err['details']);
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      return ApiException(0, 'NETWORK', 'No connection');
    }
    return ApiException(e.response?.statusCode ?? 0, 'HTTP_ERROR', e.message ?? 'Error');
  }
}

/// Stable per-attempt key so a retried checkout never creates a second order.
String newIdempotencyKey() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
