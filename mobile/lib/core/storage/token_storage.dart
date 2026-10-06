import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _timeout = Duration(seconds: 2);

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance().timeout(_timeout);
        await prefs.setString(_tokenKey, token);
        return;
      }
      await _storage.write(key: _tokenKey, value: token).timeout(_timeout);
    } catch (_) {}
  }

  Future<String?> readToken() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance().timeout(_timeout);
        return prefs.getString(_tokenKey);
      }
      return await _storage.read(key: _tokenKey).timeout(_timeout);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearToken() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance().timeout(_timeout);
        await prefs.remove(_tokenKey);
        return;
      }
      await _storage.delete(key: _tokenKey).timeout(_timeout);
    } catch (_) {}
  }
}
