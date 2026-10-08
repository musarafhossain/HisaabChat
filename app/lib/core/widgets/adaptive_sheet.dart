import 'package:flutter/material.dart';
import 'package:hisaabchat/core/widgets/window_class.dart';

/// Opens [child] as a bottom sheet on phones and a dialog on wider windows.
///
/// The sheet is capped at 90% of the screen (the drag handle sits above the
/// content, so letting the content take the full height would push its
/// bottom, usually the submit button, off-screen) and lifts above the
/// keyboard.
Future<T?> showAdaptiveSheet<T>(BuildContext context, {required Widget child, double maxDialogWidth = 520}) {
  if (context.windowClass == WindowClass.compact) {
    return showModalBottomSheet<T>(
      context: context,
      // Over the whole app, not just the current tab (covers the tab bar and +).
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: (media.size.height - media.viewInsets.bottom) * 0.9 - 48),
            child: child,
          ),
        );
      },
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxDialogWidth, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: child,
      ),
    ),
  );
}
