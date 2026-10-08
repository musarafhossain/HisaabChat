import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/network/api_exception.dart';

/// Thin strip above content that couldn't be refreshed: "Can't reach the
/// server" with a retry. Older data (if any) stays visible underneath.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  static String messageFor(Object error) {
    if (error is ApiException) {
      return error.isNetworkError ? 'You’re offline. Can’t reach the server.' : error.message;
    }
    return 'Something went wrong.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.warning.withValues(alpha: 0.14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Icon(AppIcons.offline, size: 20, color: colors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text(messageFor(error), style: TextStyle(fontSize: 13.5, color: colors.textPrimary)),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
