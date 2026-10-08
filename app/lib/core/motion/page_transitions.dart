import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/core/motion/motion.dart';

/// Fade-through: switching between top-level sections (tabs, rail items).
CustomTransitionPage<void> fadeThroughPage({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: Motion.medium,
    reverseTransitionDuration: Motion.medium,
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
CustomTransitionPage<void> sharedAxisPage({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: Motion.long,
    reverseTransitionDuration: Motion.long,
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
