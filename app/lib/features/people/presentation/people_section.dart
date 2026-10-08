import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/list_detail_layout.dart';
import 'package:hisaabchat/core/widgets/search_pill.dart';
import 'package:hisaabchat/core/widgets/window_class.dart';
import 'package:hisaabchat/features/people/data/person.dart';
import 'package:hisaabchat/features/people/people_controller.dart';
import 'package:hisaabchat/features/people/presentation/people_widgets.dart';
import 'package:hisaabchat/features/people/presentation/person_form.dart';
import 'package:hisaabchat/features/people/presentation/person_thread.dart';

/// People: who owes you and whom you owe. Each person is a chat.
class PeopleSection extends ConsumerWidget {
  const PeopleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedPersonProvider);
    return ListDetailLayout(
      list: const _PeopleList(),
      detail: selectedId == null
          ? const EmptyDetailPane(icon: AppIcons.people, message: 'Select someone to see what you lent and borrowed')
          : PersonThread(key: ValueKey('person-$selectedId'), personId: selectedId, fullScreen: false),
    );
  }
}

/// "You'll get ₹X · You owe ₹Y" (also used on Home).
class PeopleTotalsCard extends StatelessWidget {
  const PeopleTotalsCard({required this.youGet, required this.youOwe, super.key, this.onTap});

  final int youGet;
  final int youOwe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget stat(String label, int paise, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
          Text(
            Money.format(paise),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          child: Row(
            children: [
              stat('You’ll get', youGet, colors.income),
              stat('You owe', youOwe, colors.expense),
              if (onTap != null) Icon(AppIcons.chevron, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleList extends ConsumerStatefulWidget {
  const _PeopleList();

  @override
  ConsumerState<_PeopleList> createState() => _PeopleListState();
}

class _PeopleListState extends ConsumerState<_PeopleList> {
  String _query = '';
  int _filter = 0; // All · Owe you · You owe
  bool _showArchived = false;

  void _open(Person person) {
    if (context.windowClass == WindowClass.expanded) {
      ref.read(selectedPersonProvider.notifier).select(person.id);
    } else {
      context.go('/people/${person.id}');
    }
  }

  bool _matches(Person p) =>
      (_query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase())) &&
      switch (_filter) {
        1 => p.balance > 0,
        2 => p.balance < 0,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleProvider);
    final colors = context.colors;
    return switch (people) {
      AsyncValue(:final value?) when value.people.isEmpty => EmptyState(
        icon: AppIcons.people,
        title: 'No one yet',
        message: 'Add a friend to keep track of money you lend them or borrow from them.',
        action: FilledButton.icon(
          onPressed: () => showPersonForm(context),
          icon: const Icon(AppIcons.addPerson),
          label: const Text('Add person'),
        ),
      ),
      AsyncValue(:final value?) => _buildList(context, value),
      AsyncError(:final error) => EmptyState(
        icon: AppIcons.offline,
        title: 'Couldn’t load people',
        message: error is ApiException ? error.message : '$error',
        action: FilledButton.icon(
          onPressed: () => ref.read(peopleProvider.notifier).refresh(),
          icon: const Icon(AppIcons.refresh),
          label: const Text('Try again'),
        ),
      ),
      _ => Center(child: CircularProgressIndicator(color: colors.primary)),
    };
  }

  Widget _buildList(BuildContext context, PeopleState state) {
    final colors = context.colors;
    final selectedId = ref.watch(selectedPersonProvider);
    final active = state.active.where(_matches).toList();
    final archived = state.archived.where(_matches).toList();
    final wide = context.windowClass == WindowClass.expanded;

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => ref.read(peopleProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: PeopleTotalsCard(youGet: state.youGet, youOwe: state.youOwe),
          ),
          SearchPill(hint: 'Search people', onChanged: (value) => setState(() => _query = value.trim())),
          FilterChipsRow(
            labels: const ['All', 'Owe you', 'You owe'],
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          if (active.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No one matches',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          for (final (i, person) in active.indexed)
            FadeSlideIn(
              key: ValueKey(person.id),
              index: i,
              child: PersonTile(person: person, selected: wide && person.id == selectedId, onTap: () => _open(person)),
            ),
          if (state.archived.isNotEmpty) ...[
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(AppIcons.archive, color: colors.textSecondary),
              title: Text('Archived (${state.archived.length})'),
              trailing: AnimatedRotation(
                turns: _showArchived ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(AppIcons.chevron, color: colors.textSecondary),
              ),
              onTap: () => setState(() => _showArchived = !_showArchived),
            ),
            if (_showArchived)
              for (final person in archived)
                PersonTile(person: person, selected: wide && person.id == selectedId, onTap: () => _open(person)),
          ],
        ],
      ),
    );
  }
}
