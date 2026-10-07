import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/providers.dart';
import 'package:stock_management/core/storage/token_storage.dart';
import 'package:stock_management/core/utils/jwt.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/data/models/user_account.dart';
import 'package:stock_management/data/services/service_providers.dart';

enum SessionRestoreOutcome {
  /// No stored session: go to login.
  none,

  /// Token validated by the server.
  authenticated,

  /// Token expired locally or rejected by the server (401): session cleared.
  expired,

  /// Session was issued by another API_BASE_URL: session cleared.
  apiChanged,

  /// Server unreachable (network, timeout, 5xx): session kept.
  offline,
}

class SessionRestoreResult {
  const SessionRestoreResult(this.outcome, {this.user, this.errorMessage});

  final SessionRestoreOutcome outcome;
  final UserAccount? user;
  final String? errorMessage;
}

class SessionRestorer {
  SessionRestorer({
    required this._storage,
    required this._fetchMe,
    required this._apiBaseUrl,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 12),
  }) : _clock = clock ?? DateTime.now;

  final TokenStorage _storage;
  final Future<UserAccount> Function() _fetchMe;
  final String _apiBaseUrl;
  final DateTime Function() _clock;
  final Duration timeout;

  Future<SessionRestoreResult> restore() async {
    final session = await _storage.readSession();
    if (session == null) {
      return const SessionRestoreResult(SessionRestoreOutcome.none);
    }

    if (normalizeApiUrl(session.apiBaseUrl) != normalizeApiUrl(_apiBaseUrl)) {
      await _storage.clearSession();
      return const SessionRestoreResult(SessionRestoreOutcome.apiChanged);
    }

    if (isJwtExpired(session.token, now: _clock())) {
      await _storage.clearSession();
      return const SessionRestoreResult(SessionRestoreOutcome.expired);
    }

    try {
      final user = await _fetchMe().timeout(timeout);
      await _storage.saveSession(sessionFor(session.token, _apiBaseUrl, user));
      return SessionRestoreResult(SessionRestoreOutcome.authenticated, user: user);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _storage.clearSession();
        return const SessionRestoreResult(SessionRestoreOutcome.expired);
      }
      return SessionRestoreResult(
        SessionRestoreOutcome.offline,
        user: _cachedUser(session),
        errorMessage: userFacingMessage(error),
      );
    } on TimeoutException {
      return SessionRestoreResult(
        SessionRestoreOutcome.offline,
        user: _cachedUser(session),
        errorMessage: 'Le serveur ne répond pas. Vérifiez votre connexion.',
      );
    } catch (error) {
      return SessionRestoreResult(
        SessionRestoreOutcome.offline,
        user: _cachedUser(session),
        errorMessage: userFacingMessage(error),
      );
    }
  }

  UserAccount? _cachedUser(StoredSession session) {
    final id = session.userId;
    final name = session.userName;
    final role = session.userRole;
    if (id == null || name == null || role == null) {
      return null;
    }
    return UserAccount(id: id, name: name, email: '', role: role, isActive: true);
  }
}

StoredSession sessionFor(String token, String apiBaseUrl, UserAccount user) {
  return StoredSession(
    token: token,
    apiBaseUrl: apiBaseUrl,
    userId: user.id,
    userName: user.name,
    userRole: user.role,
  );
}

String normalizeApiUrl(String url) {
  return url.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
}

final sessionRestorerProvider = Provider<SessionRestorer>((ref) {
  final authService = ref.watch(authServiceProvider);
  return SessionRestorer(
    storage: ref.watch(tokenStorageProvider),
    fetchMe: authService.me,
    apiBaseUrl: ref.watch(apiClientProvider).baseUrl,
  );
});
