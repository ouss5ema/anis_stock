import 'package:stock_management/core/network/api_client.dart';
import 'package:stock_management/core/network/api_endpoints.dart';
import 'package:stock_management/core/storage/token_storage.dart';
import 'package:stock_management/data/models/user_account.dart';

class AuthService {
  AuthService({
    required this._apiClient,
    required this._tokenStorage,
  });

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<AuthSession> login({required String email, required String password}) async {
    final session = await _apiClient.post(
      ApiEndpoints.login,
      body: {'email': email, 'password': password},
      parser: (data) => AuthSession.fromJson(data as Map<String, dynamic>),
    );
    await _persist(session);
    return session;
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final session = await _apiClient.post(
      ApiEndpoints.register,
      body: {'name': name, 'email': email, 'password': password},
      parser: (data) => AuthSession.fromJson(data as Map<String, dynamic>),
    );
    await _persist(session);
    return session;
  }

  Future<void> _persist(AuthSession session) {
    return _tokenStorage.saveSession(
      StoredSession(
        token: session.token,
        apiBaseUrl: _apiClient.baseUrl,
        userId: session.user.id,
        userName: session.user.name,
        userRole: session.user.role,
      ),
    );
  }

  Future<UserAccount> me() {
    return _apiClient.get(
      ApiEndpoints.me,
      parser: (data) => UserAccount.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<bool> health() async {
    try {
      await _apiClient.get(
        ApiEndpoints.health,
        parser: (data) => data,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() {
    return _tokenStorage.clearSession();
  }
}
