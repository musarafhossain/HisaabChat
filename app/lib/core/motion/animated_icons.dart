import 'package:flutter/material.dart';
import 'package:hisaabchat/core/motion/motion.dart';

/// Material Symbols icon whose variable `fill` axis animates between
/// outlined (0) and filled (1), used for selected navigation items.
class AnimatedFillIcon extends StatelessWidget {
  const AnimatedFillIcon(this.icon, {required this.filled, super.key, this.size, this.color});

  final IconData icon;
  final bool filled;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: filled ? 1 : 0),
      duration: context.motion(Motion.medium),
      curve: Motion.standard,
      builder: (context, fill, _) => Icon(icon, fill: fill, size: size, color: color),
    );
  }
}

/// Swaps between two icons with a rotate + scale morph (e.g. attach ↔ send,
/// expense ↔ income toggle).
class MorphIcon extends StatelessWidget {
  const MorphIcon({
    required this.first,
    required this.second,
    required this.showSecond,
    super.key,
    this.size,
    this.color,
    this.turns = -0.125,
  });

  final IconData first;
  final IconData second;
  final bool showSecond;
  final double? size;
  final Color? color;

  /// Rotation of the incoming icon, in full turns (-0.125 = -45°).
  final double turns;

  @override
  Widget build(BuildContext context) {
    final icon = showSecond ? second : first;
    return AnimatedSwitcher(
      duration: context.motion(Motion.short),
      switchInCurve: Motion.pop,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) => RotationTransition(
        turns: Tween<double>(begin: turns, end: 0).animate(animation),
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: Icon(icon, key: ValueKey(icon), size: size, color: color, fill: 1),
    );
  }
}
