import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/animated_amount.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/motion/motion.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/amount_field.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/budgets/budgets_controller.dart';
import 'package:hisaabchat/features/budgets/data/budget.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_form.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_widgets.dart';
import 'package:hisaabchat/features/budgets/presentation/budgets_section.dart' show periodLabel;
import 'package:hisaabchat/features/transactions/presentation/transactions_section.dart' show TransactionTile;
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';
import 'package:intl/intl.dart';

/// Full-screen budget page (phones): `/budgets/:id`.
class BudgetInfoScreen extends StatelessWidget {
  const BudgetInfoScreen({required this.budgetId, super.key, this.month});

  final String budgetId;
  final String? month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: BudgetInfoView(budgetId: budgetId, month: month, onArchived: () => Navigator.of(context).maybePop()),
    );
  }
}

/// "Contact info" style budget page (docs/04-UI-UX-Design-Brief.md §4.7).
class BudgetInfoView extends ConsumerWidget {
  const BudgetInfoView({required this.budgetId, super.key, this.month, this.onArchived});

  final String budgetId;
  final String? month;
  final VoidCallback? onArchived;

  Future<void> _archive(BuildContext context, WidgetRef ref, BudgetStatus budget) async {
    final colors = context.colors;
    final toast = AppToast.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${budget.name}?'),
        content: const Text(
          'The budget stops tracking and its categories become free for other budgets. Your transactions are kept.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(budgetMutationsProvider).archive(budget.id);
      toast.show('${budget.name} archived', kind: ToastKind.success);
      onArchived?.call();
    } on ApiException catch (error) {
      toast.show(error.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final detail = ref.watch(budgetDetailProvider((id: budgetId, month: month)));
    final value = detail.value;
    if (value == null) {
      return detail.hasError
          ? EmptyState(
              icon: AppIcons.budgets,
              title: 'Budget not found',
              message: detail.error is ApiException ? (detail.error! as ApiException).message : null,
            )
          : Center(child: CircularProgressIndicator(color: colors.primary));
    }

    final budget = value.status;
    final theme = Theme.of(context);
    final stateColor = budgetStateColor(colors, budget.state);
    final monthKey = DateFormat('yyyy-MM').format(value.periodStart);
    final stats = <(String, String)>[
      if (budget.remaining >= 0)
        ('Left', Money.format(budget.remaining))
      else
        ('Over by', Money.format(-budget.remaining)),
      if (budget.safeToSpendPerDay != null)
        ('Safe per day', Money.format(wholeRupees(budget.safeToSpendPerDay!)))
      else
        ('Type', budget.kind.label),
      ('Days left', '${budget.daysLeft}'),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Center(child: BudgetRingAvatar(budget: budget, size: 132)),
        const SizedBox(height: 14),
        Text(budget.name, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          periodLabel(value.periodStart, value.periodEnd),
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedAmount(
              budget.spent,
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600, color: stateColor),
            ),
            Text(' of ${Money.format(budget.budgeted)}', style: TextStyle(fontSize: 16, color: colors.textSecondary)),
          ],
        ),
        if (budget.hasOverride)
          Text(
            'This month only · usually ${Money.format(budget.amount)}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
          ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (i, (label, text)) in stats.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: FadeSlideIn(
                    index: i,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        child: Column(
                          children: [
                            Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: label == 'Over by' ? colors.danger : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(label, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SectionLabel('Categories'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in budget.categories)
                Chip(
                  avatar: Icon(AppIcons.byKey(category.icon), size: 18, color: category.color, fill: 1),
                  label: Text(category.name),
                ),
            ],
          ),
        ),
        const SectionLabel('Last 6 months'),
        _HistoryChart(history: value.history, color: budget.color),
        SectionLabel('Expenses this period (${value.transactions.length})'),
        if (value.transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Nothing spent yet.', style: TextStyle(color: colors.textSecondary)),
          )
        else
          for (final txn in value.transactions)
            TransactionTile(
              txn: txn,
              onTap: () => showTxnForm(context, existing: txn),
            ),
        const Divider(),
        SettingsTile(
          icon: AppIcons.edit,
          title: 'Edit budget',
          subtitle: 'Name, amount, categories, alert',
          onTap: () => showBudgetForm(context, existing: budget),
        ),
        SettingsTile(
          icon: AppIcons.month,
          title: 'Change amount for this month only',
          subtitle: budget.hasOverride ? 'Currently ${Money.format(budget.budgeted)}' : 'e.g. a higher fees month',
          onTap: () => _showOverrideDialog(context, budget, monthKey),
        ),
        SettingsTile(
          icon: AppIcons.archive,
          title: 'Archive budget',
          destructive: true,
          onTap: () => _archive(context, ref, budget),
        ),
      ],
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.history, required this.color});

  final List<BudgetHistoryPoint> history;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final budgetLine = history.last.budgeted;
    final maxY = [
      for (final point in history) point.spent,
      ?budgetLine,
    ].fold<int>(0, (a, b) => a > b ? a : b);

    return Semantics(
      label:
          'Spending for the last six months: '
          '${history.map((p) => '${_monthName(p.month)} ${Money.format(p.spent)}').join(', ')}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SizedBox(
          height: 170,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 1 : maxY / 100 * 1.15,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => colors.toastBackground,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    Money.format(history[group.x].spent),
                    TextStyle(color: colors.onToast, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        _monthName(history[value.toInt()].month),
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (budgetLine != null && budgetLine > 0)
                    HorizontalLine(
                      y: budgetLine / 100,
                      color: colors.textSecondary,
                      strokeWidth: 1.5,
                      dashArray: [5, 4],
                    ),
                ],
              ),
              barGroups: [
                for (final (i, point) in history.indexed)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: point.spent / 100,
                        width: 18,
                        color: point.budgeted != null && point.spent > point.budgeted!
                            ? colors.danger
                            : (i == history.length - 1 ? color : color.withValues(alpha: 0.45)),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  ),
              ],
            ),
            duration: context.motion(const Duration(milliseconds: 400)),
          ),
        ),
      ),
    );
  }

  static String _monthName(String month) {
    final parts = month.split('-').map(int.parse).toList();
    return DateFormat('MMM').format(DateTime(parts[0], parts[1]));
  }
}

/// "Change amount for this month only" (with reset when an override exists).
Future<void> _showOverrideDialog(BuildContext context, BudgetStatus budget, String month) async {
  final toast = AppToast.of(context);
  await showDialog<void>(
    context: context,
    builder: (context) => _OverrideDialog(budget: budget, month: month, toast: toast),
  );
}

class _OverrideDialog extends ConsumerStatefulWidget {
  const _OverrideDialog({required this.budget, required this.month, required this.toast});

  final BudgetStatus budget;
  final String month;
  final ToastHostState toast;

  @override
  ConsumerState<_OverrideDialog> createState() => _OverrideDialogState();
}

class _OverrideDialogState extends ConsumerState<_OverrideDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: Money.format(widget.budget.budgeted).replaceAll('₹', '').replaceAll(',', ''),
  );
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _saving = true);
    try {
      await action();
      widget.toast.show(message, kind: ToastKind.success);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      widget.toast.show(error.message, kind: ToastKind.error);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mutations = ref.read(budgetMutationsProvider);
    final budget = widget.budget;
    return AlertDialog(
      title: const Text('This month only'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Use a different amount for this period. Other months stay at ${Money.format(budget.amount)}.',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 16),
            AmountField(controller: _amount, hint: 'Amount', autofocus: true, textInputAction: TextInputAction.done),
          ],
        ),
      ),
      actions: [
        if (budget.hasOverride)
          TextButton(
            onPressed: _saving
                ? null
                : () => _run(
                    () => mutations.deleteOverride(budget.id, widget.month),
                    'Back to ${Money.format(budget.amount)}',
                  ),
            child: const Text('Reset'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  if (!_formKey.currentState!.validate()) return;
                  final amount = AmountField.paiseOf(_amount) ?? 0;
                  unawaited(
                    _run(
                      () => mutations.setOverride(budget.id, widget.month, amount),
                      '${budget.name}: ${Money.format(amount)} this month',
                    ),
                  );
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
