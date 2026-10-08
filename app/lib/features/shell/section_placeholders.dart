import 'package:flutter/material.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/list_detail_layout.dart';
import 'package:hisaabchat/core/widgets/search_pill.dart';

/// Placeholder for sections built in later phases, already in the final
/// layout: search + chips + list on phones, list panel + detail pane on desktop.
class SectionPlaceholder extends StatefulWidget {
  const SectionPlaceholder({
    required this.icon,
    required this.title,
    required this.message,
    required this.searchHint,
    required this.filters,
    required this.detailMessage,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String searchHint;
  final List<String> filters;
  final String detailMessage;

  @override
  State<SectionPlaceholder> createState() => _SectionPlaceholderState();
}

class _SectionPlaceholderState extends State<SectionPlaceholder> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final list = Column(
      children: [
        const SizedBox(height: 4),
        SearchPill(hint: widget.searchHint, enabled: false),
        FilterChipsRow(labels: widget.filters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        Expanded(
          child: EmptyState(icon: widget.icon, title: widget.title, message: widget.message),
        ),
      ],
    );
    return ListDetailLayout(
      list: list,
      detail: EmptyDetailPane(icon: widget.icon, message: widget.detailMessage),
    );
  }
}

class ReportsSection extends StatelessWidget {
  const ReportsSection({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: AppIcons.reports,
    title: 'Reports',
    message: 'Spending by category and monthly trends arrive in Phase 5.',
  );
}
