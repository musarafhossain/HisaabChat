import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hisaabchat/core/motion/motion.dart';

/// Short horizontal shake (3 cycles, 300 ms) used for failed saves.
/// Change [trigger] (e.g. increment a counter) to play it again.
class Shake extends StatefulWidget {
  const Shake({required this.trigger, required this.child, super.key});

  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger && !context.reduceMotion) {
      unawaited(_controller.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final dx = math.sin(t * math.pi * 2 * 3) * 8 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
