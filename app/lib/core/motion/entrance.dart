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

/// A [Hero] that stays put when motion is reduced.
class AppHero extends StatelessWidget {
  const AppHero({required this.tag, required this.child, super.key});

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) => HeroMode(
    enabled: !context.reduceMotion,
    child: Hero(tag: tag, child: child),
  );
}

/// Presses in slightly and bounces back (the send button).
class PressBounce extends StatefulWidget {
  const PressBounce({required this.child, super.key});

  final Widget child;

  @override
  State<PressBounce> createState() => _PressBounceState();
}

class _PressBounceState extends State<PressBounce> {
  bool _down = false;

  void _set({required bool down}) => setState(() => _down = down);

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(down: true),
    onPointerUp: (_) => _set(down: false),
    onPointerCancel: (_) => _set(down: false),
    child: AnimatedScale(
      scale: _down ? 0.9 : 1,
      duration: context.motion(Motion.instant),
      curve: _down ? Motion.standard : Motion.pop,
      child: widget.child,
    ),
  );
}
