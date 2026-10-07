import 'package:flutter/foundation.dart';

class AppEnv {
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'anis_stock',
  );
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
  static const String _compileTimeApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static bool get isReleaseBuild => const bool.fromEnvironment('dart.vm.product');

  static bool get isProductionBuild =>
      isReleaseBuild || const String.fromEnvironment('APP_ENV') == 'production';

  /// Chrome uses localhost. The Android emulator uses 10.0.2.2.
  /// Release APKs must pass --dart-define=API_BASE_URL=https://...
 static String get apiBaseUrl {
  if (_compileTimeApiBaseUrl.isNotEmpty) {
    if (isReleaseBuild) {
      _assertReleaseUrl(_compileTimeApiBaseUrl);
    }
    return _compileTimeApiBaseUrl;
  }

  if (isReleaseBuild) {
    throw StateError(
      'API_BASE_URL must be provided with --dart-define for a release APK.',
    );
  }

  if (kIsWeb) {
    return 'http://164.132.101.55/api';
  }

  return 'http://10.0.2.2:3000/api';
}

  static void _assertReleaseUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('localhost') ||
        lower.contains('127.0.0.1') ||
        lower.contains('10.0.2.2')) {
      throw StateError('A release APK cannot use a development API URL.');
    }
    if (!lower.startsWith('https://')) {
      throw StateError('A release APK must use an HTTPS API_BASE_URL.');
    }
  }
}
