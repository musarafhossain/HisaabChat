import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/network/api_client.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/app_logo.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';

/// Shown while the saved session is restored, and when the API can't be
/// reached at startup.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final colors = context.colors;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Hero(tag: 'app-logo', child: AppLogo(size: 88)),
              const SizedBox(height: 24),
              Text(
                'HisaabChat',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              if (auth.hasError && !auth.isLoading)
                FadeSlideIn(
                  child: Column(
                    children: [
                      Icon(AppIcons.offline, color: colors.danger, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        auth.error is ApiException ? (auth.error! as ApiException).message : 'Something went wrong',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ref.watch(apiClientProvider).baseUrl,
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.read(authControllerProvider.notifier).retry(),
                        icon: const Icon(AppIcons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              else
                SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
