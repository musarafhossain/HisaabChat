import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/core/motion/motion.dart';

/// Fade-through: switching between top-level sections (tabs, rail items).
CustomTransitionPage<void> fadeThroughPage(BuildContext context, {required LocalKey key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: context.motion(Motion.medium),
    reverseTransitionDuration: context.motion(Motion.medium),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (context.reduceMotion) return child;
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fillColor: Colors.transparent,
        child: child,
      );
    },
  );
}

/// Shared-axis X: drilling into a child page (account → thread, list → info).
CustomTransitionPage<void> sharedAxisPage(BuildContext context, {required LocalKey key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: context.motion(Motion.long),
    reverseTransitionDuration: context.motion(Motion.long),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (context.reduceMotion) return child;
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: Colors.transparent,
        child: child,
      );
    },
  );
}

/// Where [button] is on screen, relative to [overlay], or null if it isn't laid out.
Rect? globalRectOf(BuildContext button, BuildContext overlay) {
  final box = button.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero, ancestor: overlay.findRenderObject()) & box.size;
}

/// Container transform: the page grows out of the button at [from] and
/// shrinks back into it on close (FAB → full transaction form).
Route<T> containerTransformRoute<T>(BuildContext context, {required Rect from, required WidgetBuilder builder}) {
  const duration = Duration(milliseconds: 400);
  final buttonColor = Theme.of(context).colorScheme.primary;
  final pageColor = Theme.of(context).scaffoldBackgroundColor;
  return PageRouteBuilder<T>(
    fullscreenDialog: true,
    transitionDuration: context.motion(duration),
    reverseTransitionDuration: context.motion(duration),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final progress = CurvedAnimation(parent: animation, curve: Motion.enter, reverseCurve: Motion.exit);
      return LayoutBuilder(
        builder: (context, constraints) {
          final full = Offset.zero & constraints.biggest;
          return AnimatedBuilder(
            animation: progress,
            child: child,
            builder: (context, child) {
              final t = progress.value;
              return Stack(
                children: [
                  Positioned.fromRect(
                    rect: Rect.lerp(from, full, t)!,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16 * (1 - t)),
                      child: ColoredBox(
                        color: Color.lerp(buttonColor, pageColor, t)!,
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          minWidth: full.width,
                          maxWidth: full.width,
                          minHeight: full.height,
                          maxHeight: full.height,
                          // The page's content appears once the shape is mostly open.
                          child: Opacity(opacity: ((t - 0.3) / 0.7).clamp(0, 1), child: child),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}
