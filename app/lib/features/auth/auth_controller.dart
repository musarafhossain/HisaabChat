import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/config/device.dart';
import 'package:hisaabchat/core/network/api_client.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/storage/token_store.dart';
import 'package:hisaabchat/features/auth/data/app_user.dart';
import 'package:hisaabchat/features/auth/data/auth_repository.dart';

/// Session state: `AsyncData(null)` = signed out, `AsyncData(user)` = signed in,
/// `AsyncLoading` while restoring the session, `AsyncError` if the server
/// couldn't be reached on startup (the splash screen offers a retry).
class AuthController extends AsyncNotifier<AppUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  @override
  Future<AppUser?> build() async {
    // A 401 anywhere in the app means the token was revoked or expired.
    ref.listen(sessionExpiredProvider, (_, _) => unawaited(_signOutLocally()));

    final token = await _tokens.load();
    if (token == null) return null;
    try {
      return await _repo.me();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  Future<void> login({required String email, required String password}) async {
    final session = await _repo.login(email: email.trim(), password: password, deviceName: Device.name);
    await _tokens.save(session.token);
    state = AsyncData(session.user);
  }

  Future<void> register({required String fullName, required String email, required String password}) async {
    final session = await _repo.register(
      fullName: fullName.trim(),
      email: email.trim(),
      password: password,
      deviceName: Device.name,
      timezone: await Device.timezone(),
    );
    await _tokens.save(session.token);
    state = AsyncData(session.user);
  }

  /// PATCH /me and publish the updated user.
  Future<AppUser> updateProfile(Map<String, Object?> changes) async {
    final user = await _repo.updateProfile(changes);
    state = AsyncData(user);
    return user;
  }

  /// Marks the first-run setup as done (the router then leaves /onboarding).
  Future<void> completeOnboarding() async {
    state = AsyncData(await _repo.completeOnboarding());
  }

  /// Signs out this device. The local session is cleared even when offline.
  Future<void> logout() async {
    try {
      await _repo.logout();
    } on ApiException {
      // Token already invalid or no network: signing out locally is enough.
    }
    await _signOutLocally();
  }

  /// Revokes every session (all phones, PCs and browsers).
  Future<void> logoutAll() async {
    await _repo.logoutAll();
    await _signOutLocally();
  }

  /// Retry after a startup failure (e.g. the API was offline).
  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> _signOutLocally() async {
    await _tokens.clear();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
  // Startup failures are shown with a retry button instead of silent retries.
  retry: (retryCount, error) => null,
);
