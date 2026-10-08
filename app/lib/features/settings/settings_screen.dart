import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/settings/appearance_controller.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';

/// WhatsApp-style settings: profile header, then icon rows.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogoutAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out of all devices?'),
        content: const Text('You’ll be signed out on every phone, computer and browser, including this one.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            child: const Text('Log out everywhere'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authControllerProvider.notifier).logoutAll();
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final themeMode = ref.watch(appearanceProvider.select((s) => s.themeMode));
    final colors = context.colors;
    final theme = Theme.of(context);
    if (user == null) return const SizedBox.shrink();

    final themeLabel = switch (themeMode) {
      ThemeMode.system => 'System default',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          children: [
            InkWell(
              onTap: () => context.go('/settings/profile'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: colors.primary,
                      child: Text(
                        user.initials,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName ?? user.firstName, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text(user.email, style: TextStyle(color: colors.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(AppIcons.chevron, color: colors.textSecondary),
                  ],
                ),
              ),
            ),
            const Divider(),
            SettingsTile(
              icon: AppIcons.person,
              title: 'Account',
              subtitle: 'Name, time zone, month start',
              onTap: () => context.go('/settings/profile'),
            ),
            SettingsTile(
              icon: AppIcons.palette,
              title: 'Appearance',
              subtitle: 'Theme: $themeLabel · Reduce motion',
              onTap: () => context.go('/settings/appearance'),
            ),
            SettingsTile(
              icon: AppIcons.online,
              title: 'Connection',
              subtitle: 'Server status',
              onTap: () => context.go('/settings/connection'),
            ),
            const Divider(),
            SettingsTile(
              icon: AppIcons.logout,
              title: 'Log out',
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            ),
            SettingsTile(
              icon: AppIcons.devices,
              title: 'Log out of all devices',
              destructive: true,
              onTap: () => _confirmLogoutAll(context, ref),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text('HisaabChat · v1.0.0', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
