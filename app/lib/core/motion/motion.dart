import 'package:flutter/material.dart';

/// Motion tokens (docs/04-UI-UX-Design-Brief.md §2.5).
abstract final class Motion {
  static const instant = Duration(milliseconds: 100);
  static const short = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const long = Duration(milliseconds: 350);
  static const extraLong = Duration(milliseconds: 700);

  /// Things entering the screen.
  static const Curve enter = Easing.emphasizedDecelerate;

  /// Things leaving the screen.
  static const Curve exit = Easing.emphasizedAccelerate;

  /// On-screen changes (color, size).
  static const Curve standard = Easing.standard;

  /// Small "pop" (badges, check marks, send button).
  static const Curve pop = Curves.easeOutBack;

  /// Number count-ups and ring sweeps.
  static const Curve settle = Curves.easeOutCubic;

  /// Delay between staggered list items.
  static const stagger = Duration(milliseconds: 30);

  /// Only the first few visible items are staggered; later ones just appear.
  static const maxStaggeredItems = 8;
}

extension MotionContext on BuildContext {
  /// True when the OS "remove animations" setting or the in-app
  /// "Reduce motion" switch is on (the app merges both into MediaQuery).
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// [duration], or zero when motion is reduced.
  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}
