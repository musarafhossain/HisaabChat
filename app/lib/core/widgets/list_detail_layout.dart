import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/motion/motion.dart';
import 'package:hisaabchat/core/widgets/window_class.dart';

/// WhatsApp Desktop list panel + detail pane on expanded windows; just the
/// list on smaller ones (details are pushed as pages there).
class ListDetailLayout extends StatelessWidget {
  const ListDetailLayout({required this.list, required this.detail, super.key, this.listWidth = 400});

  final Widget list;
  final Widget detail;
  final double listWidth;

  @override
  Widget build(BuildContext context) {
    if (context.windowClass != WindowClass.expanded) return list;

    final colors = context.colors;
    return Row(
      children: [
        SizedBox(
          width: listWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.panel,
              border: Border(right: BorderSide(color: colors.divider)),
            ),
            child: list,
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: context.motion(Motion.medium),
            child: KeyedSubtree(key: ValueKey(detail.key ?? detail.runtimeType), child: detail),
          ),
        ),
      ],
    );
  }
}
