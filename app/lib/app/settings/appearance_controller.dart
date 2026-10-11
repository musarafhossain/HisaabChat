import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/accent.dart';
import 'package:hisaabchat/core/storage/preferences.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/auth/data/app_user.dart';

@immutable
class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = ThemeMode.system,
    this.accent = AccentColor.fallback,
    this.reduceMotion = false,
  });

  final ThemeMode themeMode;
  final AccentColor accent;
  final bool reduceMotion;

  AppearanceSettings copyWith({ThemeMode? themeMode, AccentColor? accent, bool? reduceMotion}) => AppearanceSettings(
    themeMode: themeMode ?? this.themeMode,
    accent: accent ?? this.accent,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );
}

/// Theme, accent color and motion preferences.
///
/// All are saved on the device. The theme and accent are also stored on the
/// user's profile, so signing in on a new device picks up the same look.
class AppearanceController extends Notifier<AppearanceSettings> {
  static const _themeKey = 'appearance.theme';
  static const _motionKey = 'appearance.reduceMotion';
  static const _accentKey = 'appearance.accent';

  @override
  AppearanceSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    // Adopt the profile's theme when a (different) user signs in.
    ref.listen(authControllerProvider, (previous, next) {
      final user = next.value;
      if (user != null && previous?.value?.id != user.id) {
        _apply(themeMode: user.theme);
        _applyAccent(user.accent);
      }
    });

    return AppearanceSettings(
      themeMode: AppUser.themeModeFromApi(prefs.getString(_themeKey)),
      accent: AccentColor.fromApi(prefs.getString(_accentKey)),
      reduceMotion: prefs.getBool(_motionKey) ?? false,
    );
  }

  /// System → Light → Dark → System.
  void cycleThemeMode() => setThemeMode(switch (state.themeMode) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  });

  void setThemeMode(ThemeMode mode) {
    _apply(themeMode: mode);
    final signedIn = ref.read(authControllerProvider).value != null;
    if (signedIn) {
      // Best effort: the local choice already applies even if this fails.
      unawaited(
        ref
            .read(authControllerProvider.notifier)
            .updateProfile({'theme': AppUser.themeModeToApi(mode)})
            .then<void>((_) {}, onError: (Object _) {}),
      );
    }
  }

  /// Recolors the app now and saves the choice to the profile (best effort).
  void setAccent(AccentColor accent) {
    _applyAccent(accent);
    final signedIn = ref.read(authControllerProvider).value != null;
    if (signedIn) {
      unawaited(
        ref
            .read(authControllerProvider.notifier)
            .updateProfile({'accentColor': accent.api})
            .then<void>((_) {}, onError: (Object _) {}),
      );
    }
  }

  void setReduceMotion({required bool value}) {
    state = state.copyWith(reduceMotion: value);
    unawaited(ref.read(sharedPreferencesProvider).setBool(_motionKey, value));
  }

  void _applyAccent(AccentColor accent) {
    state = state.copyWith(accent: accent);
    unawaited(ref.read(sharedPreferencesProvider).setString(_accentKey, accent.api));
  }

  void _apply({required ThemeMode themeMode}) {
    state = state.copyWith(themeMode: themeMode);
    unawaited(ref.read(sharedPreferencesProvider).setString(_themeKey, AppUser.themeModeToApi(themeMode)));
  }
}

final appearanceProvider = NotifierProvider<AppearanceController, AppearanceSettings>(AppearanceController.new);
