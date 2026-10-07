import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session persisted between app launches. Holds no password and no
/// sensitive data besides the JWT itself.
class StoredSession {
  const StoredSession({
    required this.token,
    required this.apiBaseUrl,
    this.userId,
    this.userName,
    this.userRole,
  });

  final String token;
  final String apiBaseUrl;
  final String? userId;
  final String? userName;
  final String? userRole;

  Map<String, dynamic> toJson() => {
        'token': token,
        'apiBaseUrl': apiBaseUrl,
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
      };

  static StoredSession? fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final apiBaseUrl = json['apiBaseUrl'];
    if (token is! String || token.isEmpty || apiBaseUrl is! String) {
      return null;
    }
    return StoredSession(
      token: token,
      apiBaseUrl: apiBaseUrl,
      userId: json['userId'] as String?,
      userName: json['userName'] as String?,
      userRole: json['userRole'] as String?,
    );
  }
}

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: true,
              ),
            );

  static const _sessionKey = 'auth_session';
  static const _legacyTokenKey = 'auth_token';
  static const _timeout = Duration(seconds: 5);

  final FlutterSecureStorage _storage;

  /// In-memory copy so each HTTP request does not hit the keystore.
  String? _cachedToken;
  bool _cacheLoaded = false;

  Future<void> saveSession(StoredSession session) async {
    _cachedToken = session.token;
    _cacheLoaded = true;
    try {
      await _write(_sessionKey, jsonEncode(session.toJson()));
      await _delete(_legacyTokenKey);
    } catch (error) {
      debugPrint('TokenStorage: unable to persist session ($error)');
    }
  }

  Future<StoredSession?> readSession() async {
    try {
      final raw = await _read(_sessionKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final session = StoredSession.fromJson(decoded);
      _cachedToken = session?.token;
      _cacheLoaded = true;
      return session;
    } catch (error) {
      debugPrint('TokenStorage: unable to read session ($error)');
      return null;
    }
  }

  Future<String?> readToken() async {
    if (_cacheLoaded) {
      return _cachedToken;
    }
    return (await readSession())?.token;
  }

  Future<void> clearSession() async {
    _cachedToken = null;
    _cacheLoaded = true;
    try {
      await _delete(_sessionKey);
      await _delete(_legacyTokenKey);
    } catch (error) {
      debugPrint('TokenStorage: unable to clear session ($error)');
    }
  }

  Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance().timeout(_timeout);
      return prefs.getString(key);
    }
    return _storage.read(key: key).timeout(_timeout);
  }

  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance().timeout(_timeout);
      await prefs.setString(key, value);
      return;
    }
    await _storage.write(key: key, value: value).timeout(_timeout);
  }

  Future<void> _delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance().timeout(_timeout);
      await prefs.remove(key);
      return;
    }
    await _storage.delete(key: key).timeout(_timeout);
  }
}
