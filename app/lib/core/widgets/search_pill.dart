import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/motion.dart';

/// Rounded grey search field shown above lists (WhatsApp style), with a
/// clear (✕) button once something is typed.
class SearchPill extends StatefulWidget {
  const SearchPill({
    required this.hint,
    super.key,
    this.onChanged,
    this.controller,
    this.enabled = true,
    this.autofocus = false,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool enabled;
  final bool autofocus;

  @override
  State<SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<SearchPill> {
  TextEditingController? _own;

  TextEditingController get _controller => widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(SearchPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _own)?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _own?.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _controller,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.search,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(AppIcons.search, color: colors.textSecondary),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: Icon(AppIcons.close, size: 20, color: colors.textSecondary),
                    onPressed: _clear,
                  ),
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
