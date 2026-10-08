import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/animated_amount.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/motion/ring_progress.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/list_detail_layout.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/core/widgets/window_class.dart';
import 'package:hisaabchat/features/budgets/budgets_controller.dart';
import 'package:hisaabchat/features/budgets/data/budget.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_form.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_info.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_widgets.dart';
import 'package:hisaabchat/features/categories/categories_controller.dart';
import 'package:hisaabchat/features/categories/data/category.dart';
import 'package:intl/intl.dart';

/// "October 2026", or "25 Sep – 24 Oct" when months start mid-month.
String periodLabel(DateTime start, DateTime end) {
  if (start.day == 1) return DateFormat('MMMM y').format(start);
  return '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(end)}';
}

String shiftMonth(String month, int by) {
  final parts = month.split('-').map(int.parse).toList();
  final shifted = DateTime(parts[0], parts[1] + by);
  return DateFormat('yyyy-MM').format(shifted);
}

/// Budgets tab (docs/04-UI-UX-Design-Brief.md §4.6).
class BudgetsSection extends ConsumerWidget {
  const BudgetsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedBudgetProvider);
    final month = ref.watch(budgetMonthProvider);
    return ListDetailLayout(
      list: const _BudgetList(),
      detail: selected == null
          ? const EmptyDetailPane(icon: AppIcons.budgets, message: 'Select a budget to see how it’s going')
          : Material(
              key: ValueKey('$selected-$month'),
              child: BudgetInfoView(budgetId: selected, month: month),
            ),
    );
  }
}

class _BudgetList extends ConsumerWidget {
  const _BudgetList();

  void _open(BuildContext context, WidgetRef ref, BudgetStatus budget) {
    if (context.windowClass == WindowClass.expanded) {
      ref.read(selectedBudgetProvider.notifier).select(budget.id);
    } else {
      final month = ref.read(budgetMonthProvider);
      unawaited(context.push('/budgets/${budget.id}${month == null ? '' : '?month=$month'}'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final month = ref.watch(budgetMonthProvider);
    final overview = ref.watch(budgetsOverviewProvider(month));
    final selected = ref.watch(selectedBudgetProvider);
    final value = overview.value;

    if (value == null) {
      return overview.hasError
          ? EmptyState(
              icon: AppIcons.offline,
              title: 'Couldn’t load budgets',
              message: overview.error is ApiException ? (overview.error! as ApiException).message : '${overview.error}',
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(budgetsOverviewProvider(month)),
                icon: const Icon(AppIcons.refresh),
                label: const Text('Try again'),
              ),
            )
          : Center(child: CircularProgressIndicator(color: colors.primary));
    }

    final current = month == null;
    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => ref.refresh(budgetsOverviewProvider(month).future),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _MonthSwitcher(overview: value),
          if (value.budgets.isEmpty)
            const _Templates()
          else ...[
            _Summary(overview: value, current: current),
            for (final (i, budget) in value.budgets.indexed)
              FadeSlideIn(
                key: ValueKey(budget.id),
                index: i,
                child: BudgetTile(
                  budget: budget,
                  selected: selected == budget.id && context.windowClass == WindowClass.expanded,
                  onTap: () => _open(context, ref, budget),
                ),
              ),
            ChatTile(
              leading: IconAvatar(icon: AppIcons.byKey('more_horiz'), color: colors.textSecondary),
              title: 'Not in any budget',
              subtitle: 'Spending in categories without a budget',
              trailing: Text(
                Money.format(value.unbudgeted),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const _Templates(compact: true),
          ],
        ],
      ),
    );
  }
}

class _MonthSwitcher extends ConsumerWidget {
  const _MonthSwitcher({required this.overview});

  final BudgetsOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(budgetMonthProvider.notifier);
    final current = ref.watch(budgetMonthProvider) == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(AppIcons.back),
            onPressed: () => notifier.show(shiftMonth(overview.month, -1)),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  periodLabel(overview.periodStart, overview.periodEnd),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
                ),
                if (!current)
                  TextButton(
                    onPressed: () => notifier.show(null),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Back to this month'),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(AppIcons.forward),
            onPressed: () => notifier.show(shiftMonth(overview.month, 1)),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.overview, required this.current});

  final BudgetsOverview overview;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final over = overview.remaining < 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              RingProgress(
                progress: overview.progress,
                size: 84,
                strokeWidth: 7,
                semanticsLabel: 'All budgets',
                child: Text(
                  '${(overview.progress * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spent of budgeted', style: TextStyle(color: colors.textSecondary)),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        AnimatedAmount(
                          overview.spent,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          ' / ${Money.format(overview.budgeted)}',
                          style: TextStyle(color: colors.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (over)
                          'Over by ${Money.format(-overview.remaining)}'
                        else
                          '${Money.format(overview.remaining)} left',
                        if (current) '${overview.daysLeft} ${overview.daysLeft == 1 ? 'day' : 'days'} to go',
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: over ? colors.danger : colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Suggested budgets (Room Rent, Food & Groceries, Bike EMI + Petrol,
/// Education) whose categories are still free.
class _Templates extends ConsumerWidget {
  const _Templates({this.compact = false});

  /// Below an existing list: a short "Add another" section.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final categories = ref.watch(categoriesProvider).value ?? const <TxnCategory>[];
    bool available(BudgetTemplate t) => categories.any(
      (c) => t.categoryNames.contains(c.name) && c.type == CategoryType.expense && !c.archived && c.budgetId == null,
    );
    final templates = BudgetTemplate.all.where(available).toList();

    final custom = ChatTile(
      leading: IconAvatar(icon: AppIcons.addBudget, color: colors.primary),
      title: 'Create your own',
      subtitle: 'Pick any categories, e.g. Shopping + Entertainment',
      onTap: () => showBudgetForm(context),
    );

    if (compact) {
      if (templates.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Suggested'),
          for (final t in templates)
            ChatTile(
              leading: IconAvatar(icon: AppIcons.byKey(t.icon), color: colors.primary),
              title: t.name,
              subtitle: t.hint,
              trailing: Icon(AppIcons.add, color: colors.primary),
              onTap: () => showBudgetForm(context, template: t),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: colors.inputFill,
                child: Icon(AppIcons.budgets, size: 36, color: colors.primary),
              ),
              const SizedBox(height: 14),
              Text('Set your first budget', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Budgets warn you before you overspend. Start with a suggestion or make your own.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        for (final (i, t) in templates.indexed)
          FadeSlideIn(
            index: i,
            child: ChatTile(
              leading: IconAvatar(icon: AppIcons.byKey(t.icon), color: colors.primary),
              title: t.name,
              subtitle: '${t.kind.label} · ${t.hint}',
              trailing: Icon(AppIcons.add, color: colors.primary),
              onTap: () => showBudgetForm(context, template: t),
            ),
          ),
        custom,
      ],
    );
  }
}
