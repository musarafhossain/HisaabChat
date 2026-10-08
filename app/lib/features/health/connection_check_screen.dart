import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/settings/appearance_controller.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/animated_amount.dart';
import 'package:hisaabchat/core/motion/animated_icons.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/motion/ring_progress.dart';
import 'package:hisaabchat/core/network/api_client.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/features/health/health_repository.dart';

/// Settings → Connection: shows whether this device can reach the API and the
/// database, plus a small preview of the theme, icons and motion widgets.
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
              children: const [
                FadeSlideIn(child: _ApiStatusCard()),
                SizedBox(height: 24),
                FadeSlideIn(index: 1, child: _DesignPreview()),
              ],
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

class _DesignPreview extends StatefulWidget {
  const _DesignPreview();

  @override
  State<_DesignPreview> createState() => _DesignPreviewState();
}

class _DesignPreviewState extends State<_DesignPreview> {
  int _balance = 4825000;
  double _food = 0.62;

  void _spend() => setState(() {
    _balance -= 54000;
    _food = (_food + 0.12).clamp(0, 1.3);
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    Widget budget(String label, IconData icon, double value, Color tint) => Column(
      children: [
        RingProgress(
          progress: value,
          semanticsLabel: '$label budget',
          child: CircleAvatar(
            radius: 22,
            backgroundColor: tint.withValues(alpha: 0.15),
            child: Icon(icon, color: tint, fill: 1),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: theme.textTheme.labelMedium),
        Text('${(value * 100).round()}%', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Design preview', style: theme.textTheme.titleSmall?.copyWith(color: colors.textSecondary)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total balance', style: TextStyle(color: colors.textSecondary)),
                AnimatedAmount(_balance, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            budget('Rent', AppIcons.byKey('home'), 1, const Color(0xFF4F46E5)),
            budget('Food', AppIcons.byKey('shopping_cart'), _food, const Color(0xFF10B981)),
            budget('Bike', AppIcons.byKey('two_wheeler'), 0.78, const Color(0xFF8B5CF6)),
            budget('Education', AppIcons.byKey('school'), 0.4, const Color(0xFF0EA5E9)),
          ],
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
            child: Icon(AppIcons.byKey('shopping_cart'), color: const Color(0xFF10B981), fill: 1),
          ),
          title: const Text('Food & Groceries'),
          subtitle: const Text('Cash · Big Bazaar'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money.format(-54000),
                style: TextStyle(color: colors.expense, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Text('7:45 PM', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          child: FilledButton.icon(
            onPressed: _spend,
            icon: const Icon(AppIcons.send, fill: 1),
            label: const Text('Spend ₹540 (animation test)'),
          ),
        ),
      ],
    );
  }
}
