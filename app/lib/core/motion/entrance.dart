import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hisaabchat/core/motion/motion.dart';

/// Fade + slight slide-up entrance. Pass [index] to stagger list items;
/// only the first [Motion.maxStaggeredItems] are delayed.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({required this.child, super.key, this.index = 0, this.offset = 8});

  final Widget child;
  final int index;

  /// Slide distance in logical pixels.
  final double offset;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    final step = index.clamp(0, Motion.maxStaggeredItems);
    return child
        .animate(delay: Motion.stagger * step)
        .fadeIn(duration: Motion.medium, curve: Motion.enter)
        .moveY(begin: offset, end: 0, duration: Motion.medium, curve: Motion.enter);
  }
}

/// Scale-in "pop" for badges and check marks.
class PopIn extends StatelessWidget {
  const PopIn({required this.child, super.key, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    return child
        .animate(delay: delay)
        .scale(
          begin: Offset.zero,
          end: const Offset(1, 1),
          duration: const Duration(milliseconds: 200),
          curve: Motion.pop,
        );
  }
}
