import 'package:flutter/widgets.dart';

/// Material 3 window size classes (docs/04-UI-UX-Design-Brief.md §3.1).
/// Layout depends on width, never on platform, so resizing a Windows window
/// or browser tab switches layouts live.
enum WindowClass {
  /// < 600 dp: phones. Bottom navigation bar + FAB.
  compact,

  /// 600–839 dp: small tablets, narrow windows. Icon rail, one pane.
  medium,

  /// ≥ 840 dp: desktop & web. Icon rail + list panel + detail pane.
  expanded
  ;

  static WindowClass of(BuildContext context) => fromWidth(MediaQuery.sizeOf(context).width);

  static WindowClass fromWidth(double width) {
    if (width < 600) return compact;
    if (width < 840) return medium;
    return expanded;
  }
}

extension WindowClassContext on BuildContext {
  WindowClass get windowClass => WindowClass.of(this);
}
