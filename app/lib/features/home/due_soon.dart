import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/amount_field.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/people/presentation/people_widgets.dart';
import 'package:hisaabchat/features/recurring/data/recurring.dart';
import 'package:hisaabchat/features/recurring/recurring_controller.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';

/// Home's "Due soon" (docs/03-AppFlow.md §3.9): reminders waiting for
/// Confirm/Skip, what repeats in the next 7 days, and lend/borrow due dates.
/// Hidden when there's nothing due.
class DueSoon extends ConsumerWidget {
  const DueSoon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingProvider).value;
    if (upcoming == null || upcoming.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 8, 2),
          child: Row(
            children: [
              Text(
                'Due soon',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.textSecondary),
              ),
              const SizedBox(width: 8),
              CountBadge(upcoming.count),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/settings/recurring'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('Recurring'),
              ),
            ],
          ),
        ),
        for (final occurrence in upcoming.pending) _PendingTile(occurrence: occurrence, today: upcoming.today),
        for (final due in upcoming.dues)
          ChatTile(
            onTap: () => context.go('/people/${due.personId}'),
            leading: PersonAvatar(name: _initials(due.personName), color: due.personColor),
            title: due.lent ? '${due.personName} to pay you back' : 'Pay back ${due.personName}',
            subtitle: 'Due ${dueLabel(due.dueDate, upcoming.today)}',
            trailing: _amount(context, due.amount, due.lent ? colors.income : colors.expense),
          ),
        for (final item in upcoming.upcoming)
          ChatTile(
            onTap: () => context.go('/settings/recurring'),
            leading: _ruleAvatar(context, item.rule),
            title: item.rule.title,
            subtitle:
                '${_capitalized(dueLabel(item.date, upcoming.today))} · '
                '${item.rule.autoCreate ? 'Adds itself' : 'Remind me'}',
            trailing: _amount(context, _signed(item.rule), _color(context, item.rule.type)),
          ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  static String _capitalized(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

int _signed(RecurringRule rule) => rule.type == TxnType.expense ? -rule.amount : rule.amount;

Color _color(BuildContext context, TxnType type) => switch (type) {
  TxnType.income => context.colors.income,
  TxnType.expense => context.colors.expense,
  _ => context.colors.transfer,
};

Widget _ruleAvatar(BuildContext context, RecurringRule rule) => IconAvatar(
  icon: rule.icon(AppIcons.byKey, AppIcons.transfer),
  color: rule.type == TxnType.transfer ? context.colors.transfer : rule.colorOr(context.colors.primary),
);

Widget _amount(BuildContext context, int paise, Color color) => Text(
  Money.format(paise, signed: paise > 0),
  style: TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  ),
);

/// A remind-me occurrence with Skip and Confirm.
class _PendingTile extends ConsumerStatefulWidget {
  const _PendingTile({required this.occurrence, required this.today});

  final PendingOccurrence occurrence;
  final DateTime today;

  @override
  ConsumerState<_PendingTile> createState() => _PendingTileState();
}

class _PendingTileState extends ConsumerState<_PendingTile> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    final toast = AppToast.of(context);
    try {
      await action();
      toast.show(done, kind: ToastKind.success);
    } on ApiException catch (error) {
      toast.show(error.message, kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final rule = widget.occurrence.rule;
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => _ConfirmDialog(rule: rule),
    );
    if (amount == null || !mounted) return;
    await _act(
      () => ref.read(recurringMutationsProvider).confirm(widget.occurrence, amount: amount),
      '${rule.title} added',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rule = widget.occurrence.rule;
    final due = dueLabel(widget.occurrence.dueDate, widget.today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChatTile(
          leading: _ruleAvatar(context, rule),
          title: rule.title,
          subtitle: 'Due $due · ${rule.account.name} · waiting for you',
          trailing: _amount(context, _signed(rule), _color(context, rule.type)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(80, 0, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _act(() => ref.read(recurringMutationsProvider).skip(widget.occurrence), 'Skipped'),
                style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
                child: const Text('Skip'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(onPressed: _busy ? null : () => unawaited(_confirm()), child: const Text('Confirm')),
            ],
          ),
        ),
      ],
    );
  }
}

/// Confirm with the usual amount, or change it for this time.
class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.rule});

  final RecurringRule rule;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  late final _amount = TextEditingController(
    text: Money.format(widget.rule.amount).replaceAll('₹', '').replaceAll(',', ''),
  );
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final paise = AmountField.paiseOf(_amount);
    if (paise == null || paise <= 0) return setState(() => _error = 'Enter an amount');
    Navigator.of(context).pop(paise);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: Text('Confirm ${widget.rule.title}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Adds it to ${widget.rule.account.name}. Change the amount if it’s different this time.',
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          AmountField(controller: _amount, hint: 'Amount', allowZero: false, errorText: _error),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
