import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/settings/appearance_controller.dart';
import 'package:hisaabchat/app/theme/accent.dart';
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
                  'Your theme and color are saved to your account and follow you to other devices.',
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
              ),
              SectionLabel('Color · ${settings.accent.label}'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final accent in AccentColor.values)
                      _AccentSwatch(
                        accent: accent,
                        selected: accent == settings.accent,
                        onTap: () => controller.setAccent(accent),
                      ),
                  ],
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

/// One accent color: a circle in that color (the shade for the current
/// light/dark mode), with a check when selected.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({required this.accent, required this.selected, required this.onTap});

  final AccentColor accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? accent.dark : accent.light;
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: '${accent.label} color',
      excludeSemantics: true,
      child: Tooltip(
        message: accent.label,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? color : Colors.transparent, width: 2),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(AppIcons.check, size: 20, color: dark ? colors.panel : Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
