import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';

/// One row of a right-click menu.
class ContextMenuItem {
  const ContextMenuItem({required this.label, required this.icon, required this.onSelected, this.destructive = false});

  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  /// Shown in red (Delete, Archive…).
  final bool destructive;
}

/// Right-click (or two-finger click) on [child] opens a menu at the pointer,
/// like WhatsApp Desktop. Touch-only devices never see it; long-press keeps
/// its own meaning (e.g. selection mode).
class ContextMenuRegion extends StatelessWidget {
  const ContextMenuRegion({required this.items, required this.child, super.key});

  /// Built when the menu opens, so it reflects the latest state.
  final List<ContextMenuItem> Function() items;
  final Widget child;

  Future<void> _open(BuildContext context, Offset position) async {
    final entries = items();
    if (entries.isEmpty) return;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final colors = context.colors;
    final chosen = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        for (final (i, item) in entries.indexed)
          PopupMenuItem(
            value: i,
            height: 40,
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: item.destructive ? colors.danger : colors.textSecondary),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: item.destructive ? colors.danger : null),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (chosen != null) entries[chosen].onSelected();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) => unawaited(_open(context, details.globalPosition)),
      child: child,
    );
  }
}

/// Runs [onDelete] when Delete is pressed somewhere inside [child], unless
/// the focus is in a text field (where Delete edits the text).
class DeleteKeyShortcut extends StatelessWidget {
  const DeleteKeyShortcut({required this.onDelete, required this.child, super.key});

  /// Null turns the shortcut off (nothing selected).
  final VoidCallback? onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.delete): _DeleteIntent()},
      child: Actions(
        actions: {_DeleteIntent: _DeleteAction(onDelete)},
        child: child,
      ),
    );
  }
}

class _DeleteIntent extends Intent {
  const _DeleteIntent();
}

class _DeleteAction extends Action<_DeleteIntent> {
  _DeleteAction(this.onDelete);

  final VoidCallback? onDelete;

  /// Off while typing, so the key reaches the text field instead.
  @override
  bool isEnabled(_DeleteIntent intent) {
    if (onDelete == null) return false;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return true;
    return focused.widget is! EditableText && focused.findAncestorStateOfType<EditableTextState>() == null;
  }

  @override
  Object? invoke(_DeleteIntent intent) {
    onDelete?.call();
    return null;
  }
}
