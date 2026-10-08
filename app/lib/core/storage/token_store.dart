import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the API access token: Android Keystore, Windows Credential Manager,
/// or encrypted browser storage on web. The value is cached in memory so the
/// HTTP interceptor can attach it synchronously.
abstract class TokenStore {
  String? get token;
  Future<String?> load();
  Future<void> save(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'hisaabchat.access_token';
  final FlutterSecureStorage _storage;
  String? _token;

  @override
  String? get token => _token;

  @override
  Future<String?> load() async {
    try {
      return _token = await _storage.read(key: _key);
    } on Exception {
      // Corrupt or inaccessible storage: behave as signed out.
      return _token = null;
    }
  }

  @override
  Future<void> save(String token) async {
    _token = token;
    await _storage.write(key: _key, value: token);
  }

  @override
  Future<void> clear() async {
    _token = null;
    await _storage.delete(key: _key);
  }
}

/// In-memory store for tests.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._token]);

  String? _token;

  @override
  String? get token => _token;

  @override
  Future<String?> load() async => _token;

  @override
  Future<void> save(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
