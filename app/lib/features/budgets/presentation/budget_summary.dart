import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/core/widgets/window_class.dart';
import 'package:hisaabchat/features/budgets/budgets_controller.dart';
import 'package:hisaabchat/features/budgets/data/budget.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_widgets.dart';
import 'package:hisaabchat/features/budgets/presentation/budgets_section.dart' show periodLabel, shiftMonth;
import 'package:intl/intl.dart';

/// Budget summary (phones): `/budgets/summary`.
class BudgetSummaryScreen extends StatelessWidget {
  const BudgetSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget summary', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
      ),
      body: const BudgetSummaryView(),
    );
  }
}

/// Where the month's budget money comes from (monthly amounts + carried),
/// each budget's own maths, and month-by-month totals. Any month can be
/// picked here; the Budgets tab itself always shows the current one.
class BudgetSummaryView extends ConsumerWidget {
  const BudgetSummaryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final month = ref.watch(budgetMonthProvider);
    final overview = ref.watch(budgetsOverviewProvider(month));
    final value = overview.value;

    if (value == null) {
      return overview.hasError
          ? EmptyState(
              icon: AppIcons.offline,
              title: 'Couldn’t load the summary',
              message: overview.error is ApiException ? (overview.error! as ApiException).message : null,
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(budgetsOverviewProvider(month)),
                icon: const Icon(AppIcons.refresh),
                label: const Text('Try again'),
              ),
            )
          : Center(child: CircularProgressIndicator(color: colors.primary));
    }

    final rolling = value.budgets.where((b) => b.rollover).length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _MonthSwitcher(overview: value),
            FadeSlideIn(child: _Totals(overview: value)),
            if (value.budgets.isNotEmpty) ...[
              const SectionLabel('Each budget'),
              for (final (i, budget) in value.budgets.indexed)
                FadeSlideIn(
                  index: 1 + i,
                  child: _BudgetRow(budget: budget, month: month),
                ),
            ],
            ChatTile(
              leading: IconAvatar(icon: AppIcons.byKey('more_horiz'), color: colors.textSecondary),
              title: 'Not in any budget',
              subtitle: 'Spending in categories without a budget',
              trailing: Text(Money.format(value.unbudgeted), style: _figure(colors.textPrimary)),
            ),
            const SectionLabel('Month by month'),
            _History(month: month, selected: value.month),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.info, size: 18, color: colors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rolling == 0
                          ? 'Carry over is off, so every month starts again at its amounts. '
                                'Turn it on for a budget in Edit budget.'
                          : 'Carry over is on for $rolling ${rolling == 1 ? 'budget' : 'budgets'}: what’s left '
                                '(or overspent) each month moves into the next.',
                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _figure(Color color, {bool bold = false}) => TextStyle(
  fontSize: 15,
  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
  color: color,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// "+₹200" / "−₹300".
String _signed(int paise) => Money.format(paise, signed: true);

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

/// Monthly amounts + carried = total; spent; left.
class _Totals extends StatelessWidget {
  const _Totals({required this.overview});

  final BudgetsOverview overview;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final over = overview.remaining < 0;

    Widget line(String label, String amount, {Color? color, bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? colors.textPrimary : colors.textSecondary,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(amount, style: _figure(color ?? colors.textPrimary, bold: bold)),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            children: [
              line('Monthly amounts', Money.format(overview.monthly)),
              if (overview.carried != 0)
                line(
                  overview.carried > 0 ? 'Carried from earlier months' : 'Overspent earlier',
                  _signed(overview.carried),
                  color: overview.carried > 0 ? colors.income : colors.expense,
                ),
              Divider(height: 16, color: colors.divider),
              line('Total this month', Money.format(overview.budgeted), bold: true),
              line('Spent', Money.format(overview.spent)),
              line(
                over ? 'Over by' : 'Left',
                Money.format(overview.remaining.abs()),
                color: over ? colors.danger : colors.income,
                bold: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One budget's maths: amount (+ carried) = total · spent · left.
class _BudgetRow extends ConsumerWidget {
  const _BudgetRow({required this.budget, required this.month});

  final BudgetStatus budget;
  final String? month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final over = budget.remaining < 0;
    final amount = budget.hasOverride
        ? '${Money.format(budget.budgeted)} this month only'
        : Money.format(budget.budgeted);
    final maths = budget.rolloverIn == 0
        ? amount
        : '$amount ${budget.rolloverIn > 0 ? '+' : '−'} ${Money.format(budget.rolloverIn.abs())} '
              '${budget.rolloverIn > 0 ? 'carried' : 'overspent'} = ${Money.format(budget.available)}';

    return ChatTile(
      onTap: () {
        if (context.windowClass == WindowClass.expanded) {
          ref.read(selectedBudgetProvider.notifier).select(budget.id);
        } else {
          unawaited(context.push('/budgets/${budget.id}${month == null ? '' : '?month=$month'}'));
        }
      },
      leading: BudgetRingAvatar(budget: budget, size: 48),
      title: budget.name,
      subtitle: maths,
      trailing: Text(
        over ? 'Over ${Money.format(-budget.remaining)}' : '${Money.format(budget.remaining)} left',
        style: _figure(over ? colors.danger : colors.textPrimary),
      ),
      trailingCaption: '${Money.format(budget.spent)} spent',
    );
  }
}

/// Six months of totals ending with the shown month; tap one to view it.
class _History extends ConsumerWidget {
  const _History({required this.month, required this.selected});

  final String? month;

  /// The month on screen ("YYYY-MM").
  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final history = ref.watch(budgetHistoryProvider(month));
    final rows = history.value;
    if (rows == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: history.hasError
            ? Text('Couldn’t load earlier months', style: TextStyle(color: colors.danger))
            : Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                ),
              ),
      );
    }

    final header = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textSecondary);
    Widget cells(List<Widget> children) => Row(
      children: [
        Expanded(flex: 3, child: children[0]),
        for (final cell in children.skip(1))
          Expanded(
            flex: 4,
            child: Align(alignment: Alignment.centerRight, child: cell),
          ),
      ],
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: cells([
            Text('Month', style: header),
            Text('Budget', style: header),
            Text('Spent', style: header),
            Text('Left', style: header),
          ]),
        ),
        for (final row in rows.reversed)
          Material(
            color: row.month == selected ? colors.chipSelected.withValues(alpha: 0.6) : Colors.transparent,
            child: InkWell(
              onTap: () {
                final now = ref.read(budgetsOverviewProvider(null)).value?.month;
                ref.read(budgetMonthProvider.notifier).show(row.month == now ? null : row.month);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Semantics(
                  label: row.budgetsCount == 0
                      ? '${_monthName(row.month)}: no budgets yet'
                      : '${_monthName(row.month)}: budget ${Money.format(row.budgeted)}, '
                            'spent ${Money.format(row.spent)}, left ${Money.format(row.remaining)}',
                  excludeSemantics: true,
                  child: cells([
                    Text(_monthName(row.month), style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (row.budgetsCount == 0) ...[
                      Text('—', style: TextStyle(color: colors.textSecondary)),
                      Text('—', style: TextStyle(color: colors.textSecondary)),
                      Text('—', style: TextStyle(color: colors.textSecondary)),
                    ] else ...[
                      Text(Money.format(row.budgeted), style: _figure(colors.textPrimary)),
                      Text(Money.format(row.spent), style: _figure(colors.textPrimary)),
                      Text(
                        Money.format(row.remaining, signed: row.remaining < 0),
                        style: _figure(row.remaining < 0 ? colors.danger : colors.income),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _monthName(String month) {
    final parts = month.split('-').map(int.parse).toList();
    return DateFormat('MMM y').format(DateTime(parts[0], parts[1]));
  }
}
