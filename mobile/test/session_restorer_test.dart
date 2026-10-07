import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/storage/token_storage.dart';
import 'package:stock_management/core/utils/jwt.dart';
import 'package:stock_management/data/models/user_account.dart';
import 'package:stock_management/features/auth/providers/session_restorer.dart';

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage([this.session]);

  StoredSession? session;
  int clearCount = 0;

  @override
  Future<StoredSession?> readSession() async => session;

  @override
  Future<String?> readToken() async => session?.token;

  @override
  Future<void> saveSession(StoredSession value) async => session = value;

  @override
  Future<void> clearSession() async {
    clearCount++;
    session = null;
  }
}

const apiUrl = 'https://stock.example.com/api';
final now = DateTime.utc(2026, 10, 7, 12);

String jwtWithExp(DateTime exp) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}'
      '.${part({'sub': 'u1', 'role': 'ADMIN', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}'
      '.signature';
}

const serverUser = UserAccount(
  id: 'u1',
  name: 'Anis',
  email: 'anis@example.com',
  role: 'ADMIN',
  isActive: true,
);

StoredSession storedSession({required String token, String apiBaseUrl = apiUrl}) {
  return StoredSession(
    token: token,
    apiBaseUrl: apiBaseUrl,
    userId: 'u1',
    userName: 'Anis',
    userRole: 'ADMIN',
  );
}

SessionRestorer restorer(FakeTokenStorage storage, Future<UserAccount> Function() fetchMe) {
  return SessionRestorer(
    storage: storage,
    fetchMe: fetchMe,
    apiBaseUrl: apiUrl,
    clock: () => now,
    timeout: const Duration(milliseconds: 50),
  );
}

void main() {
  final validToken = jwtWithExp(now.add(const Duration(days: 3)));
  final expiredToken = jwtWithExp(now.subtract(const Duration(minutes: 1)));

  test('no stored session goes to login', () async {
    final storage = FakeTokenStorage();
    final result = await restorer(storage, () async => serverUser).restore();
    expect(result.outcome, SessionRestoreOutcome.none);
  });

  test('valid token is confirmed by the server and kept', () async {
    final storage = FakeTokenStorage(storedSession(token: validToken));
    final result = await restorer(storage, () async => serverUser).restore();

    expect(result.outcome, SessionRestoreOutcome.authenticated);
    expect(result.user?.email, 'anis@example.com');
    expect(storage.session?.token, validToken);
    expect(storage.clearCount, 0);
  });

  test('locally expired token is cleared without calling the server', () async {
    final storage = FakeTokenStorage(storedSession(token: expiredToken));
    var called = false;
    final result = await restorer(storage, () async {
      called = true;
      return serverUser;
    }).restore();

    expect(result.outcome, SessionRestoreOutcome.expired);
    expect(called, isFalse);
    expect(storage.session, isNull);
  });

  test('token rejected by the server (401) is cleared', () async {
    final storage = FakeTokenStorage(storedSession(token: validToken));
    final result = await restorer(
      storage,
      () async => throw const ApiException('Invalid or expired token', statusCode: 401),
    ).restore();

    expect(result.outcome, SessionRestoreOutcome.expired);
    expect(storage.session, isNull);
  });

  test('session from another API_BASE_URL is ignored and cleared', () async {
    final storage = FakeTokenStorage(
      storedSession(token: validToken, apiBaseUrl: 'http://10.0.2.2:3000/api'),
    );
    final result = await restorer(storage, () async => serverUser).restore();

    expect(result.outcome, SessionRestoreOutcome.apiChanged);
    expect(storage.session, isNull);
  });

  test('same API with a trailing slash is still accepted', () async {
    final storage = FakeTokenStorage(storedSession(token: validToken, apiBaseUrl: '$apiUrl/'));
    final result = await restorer(storage, () async => serverUser).restore();
    expect(result.outcome, SessionRestoreOutcome.authenticated);
  });

  test('network error keeps the session and returns the cached user', () async {
    final storage = FakeTokenStorage(storedSession(token: validToken));
    final result = await restorer(
      storage,
      () async => throw const ApiException('Connexion impossible. Vérifiez votre connexion Internet.'),
    ).restore();

    expect(result.outcome, SessionRestoreOutcome.offline);
    expect(result.errorMessage, isNotNull);
    expect(result.user?.name, 'Anis');
    expect(storage.session?.token, validToken);
    expect(storage.clearCount, 0);
  });

  test('server error (5xx) keeps the session', () async {
    final storage = FakeTokenStorage(storedSession(token: validToken));
    final result = await restorer(
      storage,
      () async => throw const ApiException('Internal server error', statusCode: 502),
    ).restore();

    expect(result.outcome, SessionRestoreOutcome.offline);
    expect(storage.clearCount, 0);
  });

  test('timeout keeps the session', () async {
    final storage = FakeTokenStorage(storedSession(token: validToken));
    final result = await restorer(storage, () => Completer<UserAccount>().future).restore();

    expect(result.outcome, SessionRestoreOutcome.offline);
    expect(storage.session?.token, validToken);
  });

  group('jwt', () {
    test('reads exp and detects expiry', () {
      expect(isJwtExpired(validToken, now: now), isFalse);
      expect(isJwtExpired(expiredToken, now: now), isTrue);
    });

    test('malformed token counts as expired', () {
      expect(isJwtExpired('not-a-jwt', now: now), isTrue);
    });
  });
}
