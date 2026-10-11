import 'package:flutter/material.dart';

/// The app's accent color (Settings → Appearance). It colors buttons, tabs,
/// chips, the app name and your chat bubbles; money colors (income green,
/// expense red, transfer blue, warning amber) never change with it.
enum AccentColor {
  green('GREEN', 'Green', Color(0xFF1DAA61), Color(0xFF21C063)),
  teal('TEAL', 'Teal', Color(0xFF00897B), Color(0xFF26A69A)),
  blue('BLUE', 'Blue', Color(0xFF1E6FD9), Color(0xFF4C9AFF)),
  indigo('INDIGO', 'Indigo', Color(0xFF4F46E5), Color(0xFF818CF8)),
  purple('PURPLE', 'Purple', Color(0xFF7C3AED), Color(0xFFA78BFA)),
  pink('PINK', 'Pink', Color(0xFFD6336C), Color(0xFFF06595)),
  orange('ORANGE', 'Orange', Color(0xFFE8590C), Color(0xFFFF922B)),
  amber('AMBER', 'Amber', Color(0xFFB7791F), Color(0xFFF6C350)),
  cyan('CYAN', 'Cyan', Color(0xFF0891B2), Color(0xFF22D3EE)),
  slate('SLATE', 'Slate', Color(0xFF475569), Color(0xFF94A3B8))
  ;

  const AccentColor(this.api, this.label, this.light, this.dark);

  /// Value stored on the user's profile.
  final String api;
  final String label;

  /// Shade used in light mode (readable on white).
  final Color light;

  /// Brighter shade used in dark mode (readable on near-black).
  final Color dark;

  static const AccentColor fallback = teal;

  static AccentColor fromApi(String? value) => values.firstWhere((a) => a.api == value, orElse: () => fallback);
}
