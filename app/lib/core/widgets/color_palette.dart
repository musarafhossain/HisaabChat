import 'package:flutter/material.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/entrance.dart';

/// The 12-color palette for accounts, categories and charts
/// (docs/04-UI-UX-Design-Brief.md §2.1).
const kPaletteColors = <Color>[
  Color(0xFF16A34A), // green
  Color(0xFF4F46E5), // indigo
  Color(0xFF0EA5E9), // sky
  Color(0xFFF97316), // orange
  Color(0xFF14B8A6), // teal
  Color(0xFF8B5CF6), // violet
  Color(0xFFEC4899), // pink
  Color(0xFFF43F5E), // rose
  Color(0xFFF59E0B), // amber
  Color(0xFF06B6D4), // cyan
  Color(0xFF84CC16), // lime
  Color(0xFF64748B), // slate
];

/// Row of round color swatches with a check on the selected one.
class ColorPalettePicker extends StatelessWidget {
  const ColorPalettePicker({required this.selected, required this.onChanged, super.key});

  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final color in kPaletteColors)
          Semantics(
            button: true,
            selected: color.toARGB32() == selected.toARGB32(),
            label: 'Color',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onChanged(color),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: color,
                child: color.toARGB32() == selected.toARGB32()
                    ? const PopIn(child: Icon(AppIcons.check, color: Colors.white, size: 20))
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
