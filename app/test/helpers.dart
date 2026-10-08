import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/app/app.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/storage/preferences.dart';
import 'package:hisaabchat/core/storage/token_store.dart';
import 'package:hisaabchat/features/auth/data/app_user.dart';
import 'package:hisaabchat/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const testUser = AppUser(
  id: '0192f1d2-7c1a-7b3e-9a1e-2f6c1d0a9b11',
  email: 'asha@example.com',
  fullName: 'Asha Rao',
  initials: 'AR',
  currency: 'INR',
  timezone: 'Asia/Kolkata',
  monthStartDay: 1,
  theme: ThemeMode.light,
);

/// In-memory stand-in for the auth endpoints.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.meError});

  /// Thrown by [me] (e.g. a 401 for an expired token).
  ApiException? meError;
  int logoutCalls = 0;
  Map<String, Object?>? lastProfileUpdate;

  static const _password = 'secret-password';

  @override
  Future<AuthSession> login({required String email, required String password, required String deviceName}) async {
    if (email != testUser.email || password != _password) {
      throw const ApiException(message: 'Invalid user credentials', statusCode: 400);
    }
    return (user: testUser, token: 'oat_test');
  }

  @override
  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
    required String deviceName,
    String? timezone,
  }) async {
    if (email == testUser.email) {
      throw const ApiException(
        message: 'The email has already been taken',
        statusCode: 422,
        fieldErrors: {'email': 'The email has already been taken'},
      );
    }
    return (
      user: AppUser(
        id: 'new-user',
        email: email,
        fullName: fullName,
        initials: 'NU',
        currency: 'INR',
        timezone: timezone ?? 'Asia/Kolkata',
        monthStartDay: 1,
        theme: ThemeMode.system,
      ),
      token: 'oat_new',
    );
  }

  @override
  Future<AppUser> me() async {
    if (meError != null) throw meError!;
    return testUser;
  }

  @override
  Future<AppUser> updateProfile(Map<String, Object?> changes) async {
    lastProfileUpdate = changes;
    return testUser;
  }

  @override
  Future<AppUser> completeOnboarding() async => testUser;

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  Future<void> logoutAll() async => logoutCalls++;
}

/// Pumps the whole app with fakes and a fixed window size.
Future<({FakeAuthRepository repo, MemoryTokenStore tokens})> pumpApp(
  WidgetTester tester, {
  String? savedToken,
  FakeAuthRepository? repo,
  Size size = const Size(400, 860),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fakeRepo = repo ?? FakeAuthRepository();
  final tokens = MemoryTokenStore(savedToken);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: const HisaabChatApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (repo: fakeRepo, tokens: tokens);
}
