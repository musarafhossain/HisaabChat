import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/format/dates.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/motion.dart';
import 'package:hisaabchat/core/motion/shake.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/people/data/person.dart';
import 'package:hisaabchat/features/people/people_controller.dart';
import 'package:hisaabchat/features/people/presentation/people_widgets.dart';
import 'package:hisaabchat/features/people/presentation/person_form.dart';
import 'package:hisaabchat/features/people/presentation/settle_dialog.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:hisaabchat/features/transactions/domain/quick_entry_parser.dart';
import 'package:hisaabchat/features/transactions/presentation/doodle_wallpaper.dart';
import 'package:hisaabchat/features/transactions/presentation/thread_widgets.dart';
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';
import 'package:hisaabchat/features/transactions/transactions_controller.dart';

/// One person's chat: what you lent, borrowed, got back and paid back
/// (docs/03-AppFlow.md §3.11). Money you gave is on the right.
class PersonThread extends ConsumerWidget {
  const PersonThread({required this.personId, super.key, this.fullScreen = true});

  final String personId;

  /// false = desktop detail pane (a header instead of an AppBar).
  final bool fullScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final person = ref.watch(peopleProvider.select((s) => s.value?.byId(personId)));
    if (person == null) {
      final loading = ref.watch(peopleProvider).isLoading;
      final body = loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : const EmptyState(icon: AppIcons.people, title: 'Person not found');
      return fullScreen ? Scaffold(appBar: AppBar(), body: body) : body;
    }

    final thread = ref.watch(personThreadProvider(personId));
    final items = thread.value?.items ?? const <Txn>[];

    // Newest first (reversed list); a day chip above each day's group.
    final entries = <Object>[];
    for (var i = 0; i < items.length; i++) {
      entries.add(items[i]);
      final day = items[i].localDate;
      if (i + 1 >= items.length || !Dates.sameDay(day, items[i + 1].localDate)) entries.add(Dates.dayChip(day));
    }

    final list = switch (thread) {
      AsyncError(:final error) when thread.value == null => EmptyState(
        icon: AppIcons.offline,
        title: 'Couldn’t load entries',
        message: error is ApiException ? error.message : '$error',
        action: FilledButton.icon(
          onPressed: () => ref.invalidate(personThreadProvider(personId)),
          icon: const Icon(AppIcons.refresh),
          label: const Text('Try again'),
        ),
      ),
      _ when thread.value == null => Center(child: CircularProgressIndicator(color: colors.primary)),
      _ when items.isEmpty => Center(
        child: ThreadChip(
          text: 'Nothing with ${person.name} yet. Pick Lent or Borrowed below and type an amount.',
          icon: AppIcons.info,
        ),
      ),
      _ => ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: entries.length,
        itemBuilder: (context, index) => switch (entries[index]) {
          final Txn txn => TxnBubble(
            key: ValueKey(txn.id),
            txn: txn,
            accountId: txn.account.id,
            label: '${txn.personLabel} · ${txn.account.name}',
            onTap: () => _showEntryActions(context, ref, txn),
          ),
          final String day => ThreadChip(text: day),
          _ => const SizedBox.shrink(),
        },
      ),
    };

    final body = Column(
      children: [
        if (!fullScreen) _Header(person: person),
        Expanded(child: DoodleWallpaper(child: list)),
        _BalanceBar(person: person),
        if (person.archived)
          Container(
            width: double.infinity,
            color: colors.panel,
            padding: const EdgeInsets.all(16),
            child: Text(
              '${person.name} is archived. Unarchive them from the menu to add entries.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
          )
        else
          PersonComposer(person: person),
      ],
    );

    if (!fullScreen) return body;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _TitleRow(person: person),
        actions: [_PersonMenu(person: person)],
      ),
      body: body,
    );
  }

  /// Tap on a bubble: lend/borrow entries are edited by deleting and re-adding.
  static void _showEntryActions(BuildContext context, WidgetRef ref, Txn txn) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('${txn.labelFor(null)} · ${Money.format(txn.amount)}'),
                subtitle: Text('${txn.account.name} · ${Dates.formLabel(txn.localDate)}'),
              ),
              ListTile(
                leading: const Icon(AppIcons.delete),
                title: const Text('Delete entry'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final mutations = ref.read(txnMutationsProvider);
                  try {
                    await mutations.delete(txn.id);
                    if (context.mounted) showDeletedToast(context, ref, [txn]);
                  } on ApiException catch (error) {
                    if (context.mounted) AppToast.error(context, error.message);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen thread route (phones): `/people/:id`.
class PersonThreadScreen extends StatelessWidget {
  const PersonThreadScreen({required this.personId, super.key});

  final String personId;

  @override
  Widget build(BuildContext context) => PersonThread(personId: personId);
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Hero(tag: 'person-avatar-${person.id}', child: PersonAvatar.of(person, radius: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                person.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              Text(personStatus(person), style: TextStyle(fontSize: 13, color: colors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.panel,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: Row(
          children: [
            Expanded(child: _TitleRow(person: person)),
            _PersonMenu(person: person),
          ],
        ),
      ),
    );
  }
}

class _PersonMenu extends ConsumerWidget {
  const _PersonMenu({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> archive({required bool archived}) async {
      try {
        await ref.read(peopleProvider.notifier).setArchived(person.id, archived: archived);
        if (context.mounted) {
          AppToast.success(context, archived ? '${person.name} archived' : '${person.name} is back');
        }
      } on ApiException catch (error) {
        if (context.mounted) AppToast.error(context, error.message);
      }
    }

    return PopupMenuButton<String>(
      tooltip: 'More options',
      icon: const Icon(AppIcons.more),
      onSelected: (value) => switch (value) {
        'settle' => unawaited(showSettleDialog(context, person)),
        'edit' => unawaited(showPersonForm(context, existing: person)),
        'archive' => unawaited(archive(archived: true)),
        'unarchive' => unawaited(archive(archived: false)),
        _ => null,
      },
      itemBuilder: (context) => [
        if (!person.settled) const PopupMenuItem(value: 'settle', child: Text('Settle up')),
        const PopupMenuItem(value: 'edit', child: Text('Edit name')),
        if (person.archived)
          const PopupMenuItem(value: 'unarchive', child: Text('Unarchive'))
        else
          const PopupMenuItem(value: 'archive', child: Text('Archive')),
      ],
    );
  }
}

/// Where you stand, with a Settle up button.
class _BalanceBar extends StatelessWidget {
  const _BalanceBar({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedSize(
      duration: context.motion(Motion.medium),
      child: person.settled
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              color: colors.panel,
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      person.balance > 0
                          ? '${person.name} owes you ${Money.format(person.balance)}'
                          : 'You owe ${person.name} ${Money.format(-person.balance)}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: personStatusColor(colors, person)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => showSettleDialog(context, person),
                    icon: const Icon(AppIcons.settle),
                    label: const Text('Settle up'),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Message bar for a person: pick what happened, type "500 movie", send.
class PersonComposer extends ConsumerStatefulWidget {
  const PersonComposer({required this.person, super.key});

  final Person person;

  @override
  ConsumerState<PersonComposer> createState() => _PersonComposerState();
}

class _PersonComposerState extends ConsumerState<PersonComposer> {
  static const List<TxnType> _types = [TxnType.lend, TxnType.borrow, TxnType.collect, TxnType.repay];

  final _text = TextEditingController();
  late TxnType _type = widget.person.balance < 0 ? TxnType.repay : TxnType.lend;
  String? _accountId;
  DateTime? _dueDate;
  bool _sending = false;
  int _shake = 0;
  String? _hint;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  static String _chipLabel(TxnType type) => switch (type) {
    TxnType.lend => 'Lent',
    TxnType.borrow => 'Borrowed',
    TxnType.collect => 'Got back',
    _ => 'Paid back',
  };

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      helpText: 'Due by',
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _send(List<Account> accounts) async {
    final entry = QuickEntryParser.parse(_text.text, const []);
    final account = accounts.where((a) => a.id == _accountId).firstOrNull ?? accounts.firstOrNull;
    if (entry.amount == null || account == null) {
      setState(() {
        _shake++;
        _hint = account == null ? 'Add an account first' : 'Start with an amount, e.g. 500 movie';
      });
      return;
    }

    setState(() {
      _sending = true;
      _hint = null;
    });
    try {
      await ref.read(txnMutationsProvider).create({
        'type': _type.api,
        'amount': entry.amount,
        'accountId': account.id,
        'personId': widget.person.id,
        'date': DateTime.now().toUtc().toIso8601String(),
        'note': entry.note.isEmpty ? null : entry.note,
        if (_dueDate != null && (_type == TxnType.lend || _type == TxnType.borrow)) 'dueDate': isoDateOf(_dueDate!),
      });
      _text.clear();
      if (mounted) setState(() => _dueDate = null);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _shake++;
          _hint = error.fieldErrors.values.firstOrNull ?? error.message;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accounts = ref.watch(accountsProvider).value?.active ?? const <Account>[];
    final account = accounts.where((a) => a.id == _accountId).firstOrNull ?? accounts.firstOrNull;
    final canDue = _type == TxnType.lend || _type == TxnType.borrow;
    final direction = _type == TxnType.lend || _type == TxnType.repay ? 'from' : 'into';

    return Material(
      color: colors.panel,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final type in _types)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(_chipLabel(type)),
                          selected: _type == type,
                          onSelected: (_) => setState(() => _type = type),
                        ),
                      ),
                    if (account != null)
                      PopupMenuButton<String>(
                        tooltip: 'Choose account',
                        onSelected: (id) => setState(() => _accountId = id),
                        itemBuilder: (context) => [
                          for (final a in accounts) PopupMenuItem(value: a.id, child: Text(a.name)),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Text(
                            '$direction ${account.name}',
                            style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_hint != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                  child: Text(_hint!, style: TextStyle(fontSize: 12.5, color: colors.danger)),
                ),
              const SizedBox(height: 4),
              Shake(
                trigger: _shake,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(accounts),
                        decoration: InputDecoration(
                          hintText: 'Amount and note, e.g. 500 movie',
                          filled: true,
                          fillColor: colors.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          suffixIcon: canDue
                              ? IconButton(
                                  tooltip: _dueDate == null ? 'Add a due date' : 'Due ${Dates.dayMonth(_dueDate!)}',
                                  icon: Icon(
                                    AppIcons.upcoming,
                                    color: _dueDate == null ? colors.textSecondary : colors.primary,
                                  ),
                                  onPressed: _pickDueDate,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: _sending ? null : () => _send(accounts),
                      icon: const Icon(AppIcons.send),
                    ),
                  ],
                ),
              ),
              if (_dueDate != null && canDue)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Text(
                    'Due ${Dates.dayMonth(_dueDate!)}',
                    style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
