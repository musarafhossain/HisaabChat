import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/format/dates.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/recurring/data/recurring.dart';
import 'package:hisaabchat/features/recurring/presentation/rule_form.dart';
import 'package:hisaabchat/features/recurring/recurring_controller.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';

/// Settings → Recurring: every rule with its schedule and next date.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(recurringRulesProvider);
    final colors = context.colors;

    final body = switch (rules) {
      AsyncValue(:final value?) when value.isEmpty => EmptyState(
        icon: AppIcons.recurring,
        title: 'Nothing repeats yet',
        message:
            'Rent on the 1st, Bike EMI on the 5th, salary on the 30th: add them once and they show up '
            'every month. You can also pick “Repeat” when adding a transaction.',
        action: FilledButton.icon(
          onPressed: () => showRuleForm(context),
          icon: const Icon(AppIcons.add),
          label: const Text('New recurring'),
        ),
      ),
      AsyncValue(:final value?) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final (i, rule) in value.indexed)
            FadeSlideIn(
              index: i,
              child: _RuleTile(rule: rule),
            ),
        ],
      ),
      AsyncError(:final error) => EmptyState(
        icon: AppIcons.offline,
        title: 'Couldn’t load recurring',
        message: error is ApiException ? error.message : '$error',
        action: FilledButton.icon(
          onPressed: () => ref.invalidate(recurringRulesProvider),
          icon: const Icon(AppIcons.refresh),
          label: const Text('Try again'),
        ),
      ),
      _ => Center(child: CircularProgressIndicator(color: colors.primary)),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          IconButton(tooltip: 'New recurring', icon: const Icon(AppIcons.add), onPressed: () => showRuleForm(context)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: body),
      ),
    );
  }
}

class _RuleTile extends ConsumerWidget {
  const _RuleTile({required this.rule});

  final RecurringRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final color = rule.type == TxnType.transfer ? colors.transfer : rule.colorOr(colors.primary);

    Future<void> run(Future<void> Function() action, String done) async {
      try {
        await action();
        if (context.mounted) AppToast.success(context, done);
      } on ApiException catch (error) {
        if (context.mounted) AppToast.error(context, error.message);
      }
    }

    final mutations = ref.read(recurringMutationsProvider);
    return Opacity(
      opacity: rule.isActive ? 1 : 0.6,
      child: ChatTile(
        onTap: () => showRuleForm(context, existing: rule),
        onLongPress: () => _actions(context, run, mutations),
        leading: IconAvatar(icon: rule.icon(AppIcons.byKey, AppIcons.transfer), color: color),
        title: rule.title,
        subtitle: '${rule.scheduleLabel} · ${rule.autoCreate ? 'Auto-add' : 'Remind me'} · ${rule.account.name}',
        trailing: Text(
          Money.format(rule.type == TxnType.expense ? -rule.amount : rule.amount, signed: rule.type == TxnType.income),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: switch (rule.type) {
              TxnType.income => colors.income,
              TxnType.expense => colors.expense,
              _ => colors.transfer,
            },
          ),
        ),
        trailingCaption: rule.isActive
            ? (rule.nextDate == null ? 'Ended' : 'Next ${Dates.dayMonth(rule.nextDate!)}')
            : 'Paused',
      ),
    );
  }

  /// Long-press: pause, resume or delete.
  void _actions(
    BuildContext context,
    Future<void> Function(Future<void> Function() action, String done) run,
    RecurringMutations mutations,
  ) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        builder: (sheet) {
          void choose(Future<void> Function() action, String done) {
            Navigator.of(sheet).pop();
            unawaited(run(action, done));
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(title: Text(rule.title), subtitle: Text(rule.scheduleLabel)),
                if (rule.isActive)
                  ListTile(
                    leading: const Icon(AppIcons.sending),
                    title: const Text('Pause'),
                    onTap: () => choose(() => mutations.update(rule.id, {'isActive': false}), 'Paused'),
                  )
                else
                  ListTile(
                    leading: const Icon(AppIcons.recurring),
                    title: const Text('Resume'),
                    onTap: () => choose(() => mutations.update(rule.id, {'isActive': true}), 'Resumed'),
                  ),
                ListTile(
                  leading: const Icon(AppIcons.delete),
                  title: const Text('Delete'),
                  onTap: () => choose(() => mutations.delete(rule.id), 'Deleted. What it already added stays.'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
