import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/animated_amount.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/core/widgets/context_menu.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/list_detail_layout.dart';
import 'package:hisaabchat/core/widgets/search_pill.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/core/widgets/window_class.dart';
import 'package:hisaabchat/features/budgets/budgets_controller.dart';
import 'package:hisaabchat/features/budgets/data/budget.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_form.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_info.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_summary.dart';
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
      detail: switch (selected) {
        null => const EmptyDetailPane(icon: AppIcons.budgets, message: 'Select a budget to see how it’s going'),
        budgetSummaryKey => const Material(key: ValueKey(budgetSummaryKey), child: BudgetSummaryView()),
        _ => Material(
          key: ValueKey('$selected-$month'),
          child: BudgetInfoView(budgetId: selected, month: month),
        ),
      },
    );
  }
}

class _BudgetList extends ConsumerStatefulWidget {
  const _BudgetList();

  @override
  ConsumerState<_BudgetList> createState() => _BudgetListState();
}

class _BudgetListState extends ConsumerState<_BudgetList> {
  String _query = '';

  /// Name or any of its categories ("petrol" finds "Bike EMI + Petrol").
  bool _matches(BudgetStatus budget) {
    final q = _query.toLowerCase();
    return q.isEmpty ||
        budget.name.toLowerCase().contains(q) ||
        budget.categories.any((c) => c.name.toLowerCase().contains(q));
  }

  void _open(BuildContext context, WidgetRef ref, BudgetStatus budget) {
    // From the tab it's always this month.
    ref.read(budgetMonthProvider.notifier).show(null);
    if (context.windowClass == WindowClass.expanded) {
      ref.read(selectedBudgetProvider.notifier).select(budget.id);
    } else {
      unawaited(context.push('/budgets/${budget.id}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final overview = ref.watch(budgetsOverviewProvider(null));
    final selected = ref.watch(selectedBudgetProvider);
    final value = overview.value;

    if (value == null) {
      return overview.hasError
          ? EmptyState(
              icon: AppIcons.offline,
              title: 'Couldn’t load budgets',
              message: overview.error is ApiException ? (overview.error! as ApiException).message : '${overview.error}',
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(budgetsOverviewProvider(null)),
                icon: const Icon(AppIcons.refresh),
                label: const Text('Try again'),
              ),
            )
          : Center(child: CircularProgressIndicator(color: colors.primary));
    }

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => ref.refresh(budgetsOverviewProvider(null).future),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (value.budgets.isEmpty)
            const _Templates()
          else ...[
            _ThisMonth(overview: value, selected: selected == budgetSummaryKey),
            SearchPill(hint: 'Search budgets', onChanged: (v) => setState(() => _query = v.trim())),
            if (!value.budgets.any(_matches))
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No budgets match',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            for (final (i, budget) in value.budgets.where(_matches).indexed)
              FadeSlideIn(
                key: ValueKey(budget.id),
                index: i,
                child: ContextMenuRegion(
                  items: () => [
                    ContextMenuItem(
                      label: 'Open',
                      icon: AppIcons.forward,
                      onSelected: () => _open(context, ref, budget),
                    ),
                    ContextMenuItem(
                      label: 'Edit budget',
                      icon: AppIcons.edit,
                      onSelected: () => unawaited(showBudgetForm(context, existing: budget)),
                    ),
                  ],
                  child: BudgetTile(
                    budget: budget,
                    selected: selected == budget.id && context.windowClass == WindowClass.expanded,
                    onTap: () => _open(context, ref, budget),
                  ),
                ),
              ),
            if (_query.isEmpty) ...[
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
        ],
      ),
    );
  }
}

/// "October · 21 days left / ₹2,700 left of ₹11,500 ›": opens the Budget
/// summary (monthly amounts, carried money, month by month).
class _ThisMonth extends ConsumerWidget {
  const _ThisMonth({required this.overview, required this.selected});

  final BudgetsOverview overview;

  /// Desktop: the summary is open in the detail pane.
  final bool selected;

  void _openSummary(BuildContext context, WidgetRef ref) {
    ref.read(budgetMonthProvider.notifier).show(null);
    if (context.windowClass == WindowClass.expanded) {
      ref.read(selectedBudgetProvider.notifier).select(budgetSummaryKey);
    } else {
      unawaited(context.push('/budgets/summary'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final over = overview.remaining < 0;
    final days = overview.daysLeft;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        color: selected ? colors.chipSelected : null,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          label:
              '${over ? 'Over by ${Money.format(-overview.remaining)}' : '${Money.format(overview.remaining)} left'} '
              'of ${Money.format(overview.budgeted)} this month. Open budget summary',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => _openSummary(context, ref),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${DateFormat('MMMM').format(overview.periodStart)} · $days ${days == 1 ? 'day' : 'days'} left',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ),
                      Icon(AppIcons.chevron, color: colors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      AnimatedAmount(
                        overview.remaining.abs(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: over ? colors.danger : colors.textPrimary,
                        ),
                      ),
                      Text(
                        over
                            ? ' over · of ${Money.format(overview.budgeted)}'
                            : ' left of ${Money.format(overview.budgeted)}',
                        style: TextStyle(color: colors.textSecondary, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: overview.progress.clamp(0, 1),
                      minHeight: 6,
                      color: over ? colors.danger : colors.primary,
                      backgroundColor: colors.divider,
                    ),
                  ),
                  if (overview.carried != 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        overview.carried > 0
                            ? 'Includes ${Money.format(overview.carried)} carried over'
                            : '${Money.format(-overview.carried)} overspent earlier is taken from this month',
                        style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
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
