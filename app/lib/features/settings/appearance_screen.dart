import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/settings/appearance_controller.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            children: [
              const SectionLabel('Theme'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, icon: Icon(AppIcons.themeSystem), label: Text('System')),
                    ButtonSegment(value: ThemeMode.light, icon: Icon(AppIcons.themeLight), label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(AppIcons.themeDark), label: Text('Dark')),
                  ],
                  selected: {settings.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => controller.setThemeMode(selection.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Your theme is saved to your account and follows you to other devices.',
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
              ),
              const SectionLabel('Motion'),
              SwitchListTile(
                secondary: const Icon(AppIcons.motion),
                title: const Text('Reduce motion'),
                subtitle: const Text('Turn off slides, bounces and count-ups'),
                value: settings.reduceMotion,
                onChanged: (value) => controller.setReduceMotion(value: value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
