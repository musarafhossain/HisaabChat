import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/motion/motion.dart';

/// Budget progress ring (the "status ring" around a budget avatar).
///
/// Sweeps in from 0 on first show, animates between values afterwards, tweens
/// its color across the thresholds (green → amber → red) and pulses once with
/// a haptic tick when the value crosses [alertAt].
class RingProgress extends StatefulWidget {
  const RingProgress({
    required this.progress,
    super.key,
    this.alertAt = 0.8,
    this.size = 56,
    this.strokeWidth = 3,
    this.child,
    this.semanticsLabel,
  });

  /// Spent / budgeted. May exceed 1.
  final double progress;
  final double alertAt;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final String? semanticsLabel;

  @override
  State<RingProgress> createState() => _RingProgressState();
}

class _RingProgressState extends State<RingProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void didUpdateWidget(RingProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    final crossedAlert = oldWidget.progress < widget.alertAt && widget.progress >= widget.alertAt;
    final crossedLimit = oldWidget.progress <= 1 && widget.progress > 1;
    if ((crossedAlert || crossedLimit) && !context.reduceMotion) {
      unawaited(HapticFeedback.mediumImpact());
      unawaited(_pulse.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color _statusColor(AppColors colors, double value) {
    if (value <= 0) return colors.divider;
    if (value > 1) return colors.danger;
    if (value >= widget.alertAt) return colors.warning;
    return colors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: widget.semanticsLabel,
      value: '${(widget.progress * 100).round()} percent used',
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          // 1 → 1.08 → 1
          final scale = 1 + 0.08 * math.sin(_pulse.value * math.pi);
          return Transform.scale(scale: scale, child: child);
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.progress),
          duration: context.motion(Motion.extraLong),
          curve: Motion.settle,
          builder: (context, value, child) {
            return TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: _statusColor(colors, widget.progress)),
              duration: context.motion(Motion.medium),
              builder: (context, color, _) => RepaintBoundary(
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _RingPainter(
                    progress: value.clamp(0, 1),
                    color: color ?? colors.primary,
                    trackColor: colors.divider,
                    strokeWidth: widget.strokeWidth,
                  ),
                  child: SizedBox.square(
                    dimension: widget.size,
                    child: Center(child: child),
                  ),
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = trackColor);
    if (progress > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.trackColor != trackColor;
}
