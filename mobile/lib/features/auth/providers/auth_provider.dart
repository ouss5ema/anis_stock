import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/providers.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/data/models/user_account.dart';
import 'package:stock_management/data/services/service_providers.dart';

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
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (state.status == AuthStatus.unknown) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  final Ref _ref;

  void expireSession() {
    if (state.status == AuthStatus.authenticated) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Session expirée. Reconnectez-vous.',
      );
    }
  }

  Future<void> restoreSession() async {
    try {
      final token = await _ref.read(tokenStorageProvider).readToken();
      if (token == null || token.isEmpty) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      final user = await _ref
          .read(authServiceProvider)
          .me()
          .timeout(const Duration(seconds: 8));
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      try {
        await _ref.read(tokenStorageProvider).clearToken();
      } catch (_) {}
      state = const AuthState(status: AuthStatus.unauthenticated);
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
