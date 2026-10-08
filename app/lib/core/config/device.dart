import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

abstract final class Device {
  /// Human-readable label stored with the access token ("Android", "Windows", "Web").
  static String get name {
    if (kIsWeb) return 'Web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  /// The device's IANA time zone (e.g. "Asia/Kolkata"), or null if unknown.
  /// Never blocks for long: registration must not wait on a slow plugin.
  static Future<String?> timezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone().timeout(const Duration(seconds: 2));
      return info.identifier.isEmpty ? null : info.identifier;
    } on Object {
      return null;
    }
  }
}
