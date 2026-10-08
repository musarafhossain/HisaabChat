import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/network/api_client.dart';
import 'package:hisaabchat/features/auth/data/app_user.dart';

typedef AuthSession = ({AppUser user, String token});

/// Auth & profile endpoints (docs/02-TRD.md §4.2).
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
    required String deviceName,
    String? timezone,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      body: {
        'fullName': fullName,
        'email': email,
        'password': password,
        'passwordConfirmation': password,
        'deviceName': deviceName,
        'timezone': ?timezone,
      },
    );
    return _session(data);
  }

  Future<AuthSession> login({required String email, required String password, required String deviceName}) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: {'email': email, 'password': password, 'deviceName': deviceName},
    );
    return _session(data);
  }

  Future<AppUser> me() async => AppUser.fromJson(await _api.get<Map<String, dynamic>>('/me'));

  Future<AppUser> updateProfile(Map<String, Object?> changes) async =>
      AppUser.fromJson(await _api.patch<Map<String, dynamic>>('/me', body: changes));

  Future<AppUser> completeOnboarding() async =>
      AppUser.fromJson(await _api.post<Map<String, dynamic>>('/me/onboarding/complete'));

  Future<void> logout() => _api.post<Object?>('/auth/logout');

  Future<void> logoutAll() => _api.post<Object?>('/auth/logout-all');

  AuthSession _session(Map<String, dynamic> data) => (
    user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    token: data['token'] as String,
  );
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));
