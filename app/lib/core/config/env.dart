import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Release builds talk to production unless `--dart-define=API_BASE_URL=…`
/// says otherwise. Debug builds talk to the local AdonisJS server: the
/// Android emulator reaches the host machine through 10.0.2.2.
abstract final class Env {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// The hosted API (nginx on the VPS; health check at `/health`).
  static const productionApiBaseUrl = 'https://hisaabchat.musaraf.org.in/api/v1';

  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    if (kReleaseMode) return productionApiBaseUrl;
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return isAndroid ? 'http://10.0.2.2:3333/api/v1' : 'http://localhost:3333/api/v1';
  }
}
