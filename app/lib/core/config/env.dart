import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Pass `--dart-define=API_BASE_URL=https://api.example.com/api/v1` for real
/// builds. Without it, debug builds talk to the local AdonisJS server: the
/// Android emulator reaches the host machine through 10.0.2.2.
abstract final class Env {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return isAndroid ? 'http://10.0.2.2:3333/api/v1' : 'http://localhost:3333/api/v1';
  }
}
