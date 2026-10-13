import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:la_toscana_admin/core/api.dart';

/// Answers each request from [handler]; `null` simulates a dropped connection.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final ({int status, Object body})? Function(RequestOptions o) handler;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final r = handler(o);
    if (r == null) throw DioException.connectionError(requestOptions: o, reason: 'offline');
    return ResponseBody.fromString(jsonEncode(r.body), r.status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<(Api, TokenStore, List<String>)> _client(({int status, Object body})? Function(RequestOptions o) handler) async {
  FlutterSecureStorage.setMockInitialValues({'lt_access': 'old-access', 'lt_refresh': 'old-refresh'});
  final tokens = TokenStore();
  await tokens.load();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = _FakeAdapter(handler);
  final events = <String>[];
  final api = Api(tokens, dio: dio)..onSessionExpired = () => events.add('expired');
  return (api, tokens, events);
}

const _unauth = (status: 401, body: {'error': {'code': 'UNAUTHENTICATED', 'message': 'expired'}});

void main() {
  test('a 401 refreshes once, retries with the new token and stores the rotated pair', () async {
    final seen = <String?>[];
    final (api, tokens, events) = await _client((o) {
      if (o.path == '/api/v1/auth/refresh') return (status: 200, body: {'accessToken': 'new-access', 'refreshToken': 'new-refresh'});
      seen.add(o.headers['authorization'] as String?);
      return o.headers['authorization'] == 'Bearer new-access' ? (status: 200, body: {'ok': true}) : _unauth;
    });
    final r = await api.get<Map<String, dynamic>>('/api/v1/me');
    expect(r['ok'], true);
    expect(seen, ['Bearer old-access', 'Bearer new-access']);
    expect(tokens.refresh, 'new-refresh');
    expect(events, isEmpty);
  });

  test('a rejected refresh token signs the user out', () async {
    final (api, tokens, events) = await _client((o) => o.path == '/api/v1/auth/refresh'
        ? (status: 401, body: {'error': {'code': 'SESSION_REUSED', 'message': 'revoked'}})
        : _unauth);
    await expectLater(api.get<dynamic>('/api/v1/me'), throwsA(isA<ApiException>()));
    expect(tokens.hasSession, false);
    expect(events, ['expired']);
  });

  test('QA BUG-007: a refresh that fails for network reasons or rate limiting keeps the session', () async {
    for (final failure in <({int status, Object body})?>[
      null, // offline
      (status: 429, body: {'error': {'code': 'RATE_LIMITED', 'message': 'slow down'}}),
      (status: 503, body: {'error': {'code': 'UNAVAILABLE', 'message': 'maintenance'}}),
    ]) {
      final (api, tokens, events) = await _client((o) => o.path == '/api/v1/auth/refresh' ? failure : _unauth);
      await expectLater(api.get<dynamic>('/api/v1/me'), throwsA(isA<ApiException>()));
      expect(tokens.hasSession, true, reason: 'failure $failure must not sign out');
      expect(tokens.refresh, 'old-refresh');
      expect(events, isEmpty);
    }
  });
}
