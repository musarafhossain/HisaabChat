import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/motion.dart';

/// Rounded grey search field shown above lists (WhatsApp style).
class SearchPill extends StatelessWidget {
  const SearchPill({required this.hint, super.key, this.onChanged, this.controller, this.enabled = true});

  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(AppIcons.search, color: colors.textSecondary),
            contentPadding: EdgeInsets.zero,
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of single-select filter chips (All · Expense · Income …).
class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({required this.labels, required this.selected, required this.onSelected, super.key});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = index == selected;
          return AnimatedSwitcher(
            duration: context.motion(Motion.short),
            child: FilterChip(
              key: ValueKey(isSelected),
              label: Text(labels[index]),
              selected: isSelected,
              showCheckmark: false,
              labelStyle: isSelected ? Theme.of(context).chipTheme.secondaryLabelStyle : null,
              onSelected: (_) => onSelected(index),
            ),
          );
        },
      ),
    );
  }
}
