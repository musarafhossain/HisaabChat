import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/entrance.dart';

/// Centered icon + one friendly line + optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    super.key,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: FadeSlideIn(
          offset: 12,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colors.inputFill,
                  child: Icon(icon, size: 40, color: colors.primary),
                ),
                const SizedBox(height: 20),
                Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 20), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop detail pane before anything is selected (WhatsApp Desktop style).
class EmptyDetailPane extends StatelessWidget {
  const EmptyDetailPane({required this.icon, required this.message, super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.threadBackground,
      child: Column(
        children: [
          Expanded(
            child: EmptyState(icon: icon, title: 'HisaabChat', message: message),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.privacy, size: 14, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Your data is private to your account',
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
