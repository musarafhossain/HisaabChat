import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';

/// Calls [onLoadMore] when the user scrolls near the end of [child]'s list
/// (the bottom, or the top for a reversed chat list). Also fires once the
/// list is laid out if the first page doesn't fill the screen.
class LoadMoreListener extends StatelessWidget {
  const LoadMoreListener({required this.onLoadMore, required this.child, super.key, this.threshold = 600});

  final VoidCallback onLoadMore;
  final Widget child;

  /// How close to the end (in pixels) the next page starts loading.
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        _check(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _check(notification.metrics);
          return false;
        },
        child: child,
      ),
    );
  }

  void _check(ScrollMetrics metrics) {
    if (metrics.axis == Axis.vertical && metrics.extentAfter < threshold) onLoadMore();
  }
}

/// Small spinner at the end of a list while the next page loads.
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.primary),
        ),
      ),
    );
  }
}
