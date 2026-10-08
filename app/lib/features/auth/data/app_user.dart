import 'package:flutter/material.dart';

/// The signed-in user and their preferences (`GET /me`).
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.initials,
    required this.currency,
    required this.timezone,
    required this.monthStartDay,
    required this.theme,
    this.fullName,
    this.onboardedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    email: json['email'] as String,
    fullName: json['fullName'] as String?,
    initials: json['initials'] as String? ?? '',
    currency: json['currency'] as String? ?? 'INR',
    timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
    monthStartDay: (json['monthStartDay'] as num?)?.toInt() ?? 1,
    theme: themeModeFromApi(json['theme'] as String?),
    onboardedAt: json['onboardedAt'] == null ? null : DateTime.parse(json['onboardedAt'] as String),
  );

  final String id;
  final String email;
  final String? fullName;
  final String initials;
  final String currency;
  final String timezone;
  final int monthStartDay;
  final ThemeMode theme;
  final DateTime? onboardedAt;

  /// "Musaraf" from "Musaraf Hossain", falling back to the email name.
  String get firstName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name.split(RegExp(r'\s+')).first;
    return email.split('@').first;
  }

  static ThemeMode themeModeFromApi(String? value) => switch (value) {
    'LIGHT' => ThemeMode.light,
    'DARK' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String themeModeToApi(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'LIGHT',
    ThemeMode.dark => 'DARK',
    ThemeMode.system => 'SYSTEM',
  };
}
