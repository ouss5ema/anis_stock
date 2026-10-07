import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/providers.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/data/models/user_account.dart';
import 'package:stock_management/data/services/service_providers.dart';
import 'package:stock_management/features/auth/providers/session_restorer.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserAccount? user;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    UserAccount? user,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : user ?? this.user,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState(status: AuthStatus.unknown)) {
    _ref.read(apiClientProvider).onUnauthorized = expireSession;
    restoreSession();
  }

  static const sessionExpiredMessage = 'Session expirée. Reconnectez-vous.';

  final Ref _ref;

  void expireSession() {
    if (state.status == AuthStatus.authenticated) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: sessionExpiredMessage,
      );
    }
  }

  /// Restores the stored session before the router leaves the splash.
  /// While the server is unreachable the status stays [AuthStatus.unknown]
  /// with an [AuthState.errorMessage]: the token is kept and the splash
  /// offers to retry.
  Future<void> restoreSession() async {
    state = const AuthState(status: AuthStatus.unknown);
    SessionRestoreResult result;
    try {
      result = await _ref.read(sessionRestorerProvider).restore();
    } catch (error) {
      result = SessionRestoreResult(
        SessionRestoreOutcome.offline,
        errorMessage: userFacingMessage(error),
      );
    }
    if (!mounted) return;

    switch (result.outcome) {
      case SessionRestoreOutcome.authenticated:
        state = AuthState(status: AuthStatus.authenticated, user: result.user);
      case SessionRestoreOutcome.expired:
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: sessionExpiredMessage,
        );
      case SessionRestoreOutcome.none:
      case SessionRestoreOutcome.apiChanged:
        state = const AuthState(status: AuthStatus.unauthenticated);
      case SessionRestoreOutcome.offline:
        state = AuthState(
          status: AuthStatus.unknown,
          user: result.user,
          errorMessage: result.errorMessage ?? 'Connexion impossible. Vérifiez votre connexion Internet.',
        );
    }
  }

  /// Opens the app with the cached user when the server could not be reached
  /// at startup. The next 401 from the API still ends the session.
  void continueOffline() {
    final user = state.user;
    if (state.status == AuthStatus.unknown && user != null) {
      state = AuthState(status: AuthStatus.authenticated, user: user);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(clearError: true);
    try {
      final session = await _ref
          .read(authServiceProvider)
          .login(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 15));
      state = AuthState(status: AuthStatus.authenticated, user: session.user);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: userFacingMessage(error),
        clearUser: true,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Impossible de se connecter. Vérifiez le serveur.',
        clearUser: true,
      );
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(clearError: true);
    try {
      final session = await _ref
          .read(authServiceProvider)
          .register(
            name: name,
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 15));
      state = AuthState(status: AuthStatus.authenticated, user: session.user);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: userFacingMessage(error),
        clearUser: true,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Impossible de créer le compte. Vérifiez le serveur.',
        clearUser: true,
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _ref.read(authServiceProvider).logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// Shows or hides ADMIN actions. Display only: the backend enforces the
/// role on every sensitive route (403 otherwise).
final isAdminProvider = Provider<bool>((ref) => ref.watch(authProvider).user?.role == 'ADMIN');
