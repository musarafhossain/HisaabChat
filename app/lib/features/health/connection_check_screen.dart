import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/settings/appearance_controller.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/animated_icons.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/network/api_client.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/features/health/health_repository.dart';

/// Settings → Connection: shows whether this device can reach the API and the
/// database.
class ConnectionCheckScreen extends ConsumerWidget {
  const ConnectionCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appearanceProvider.select((s) => s.themeMode));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
            tooltip: 'Theme: ${themeMode.name}',
            onPressed: ref.read(appearanceProvider.notifier).cycleThemeMode,
            icon: MorphIcon(
              first: themeMode == ThemeMode.light ? AppIcons.themeLight : AppIcons.themeSystem,
              second: AppIcons.themeDark,
              showSecond: themeMode == ThemeMode.dark,
            ),
          ),
          IconButton(
            tooltip: 'Check again',
            onPressed: () => ref.invalidate(healthProvider),
            icon: const Icon(AppIcons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [FadeSlideIn(child: _ApiStatusCard())],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApiStatusCard extends ConsumerWidget {
  const _ApiStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final health = ref.watch(healthProvider);
    final baseUrl = ref.watch(apiClientProvider).baseUrl;

    final (IconData icon, Color color, String title, String detail) = switch (health) {
      AsyncData(:final value) when value.isHealthy => (
        AppIcons.online,
        colors.primary,
        'Connected to the API',
        'Database ${value.database} · server time ${TimeOfDay.fromDateTime(value.serverTime.toLocal()).format(context)}',
      ),
      AsyncData(:final value) => (
        AppIcons.warning,
        colors.warning,
        'API is up, database is ${value.database}',
        'Start MariaDB (XAMPP) and check backend/.env',
      ),
      AsyncError(:final error) => (
        AppIcons.offline,
        colors.danger,
        'Can’t reach the API',
        error is ApiException ? error.message : '$error',
      ),
      _ => (AppIcons.sending, colors.textSecondary, 'Checking connection…', baseUrl),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: PopIn(
                    key: ValueKey(icon),
                    child: Icon(icon, color: color, size: 32, fill: 1),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 12),
            Text(detail, style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 4),
            SelectableText(baseUrl, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            if (health.hasError) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(healthProvider),
                icon: const Icon(AppIcons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
