import 'package:flutter/material.dart';
import 'package:hisaabchat/features/accounts/data/account.dart' show parseHexColor;
import 'package:hisaabchat/features/transactions/data/txn.dart';

enum BudgetKind {
  variable('VARIABLE', 'Variable', 'Day-to-day spending, like food or petrol'),
  fixed('FIXED', 'Fixed', 'The same each month, like rent or an EMI')
  ;

  const BudgetKind(this.api, this.label, this.hint);

  final String api;
  final String label;
  final String hint;

  static BudgetKind fromApi(String value) => value == 'FIXED' ? fixed : variable;
}

enum BudgetState {
  ok,
  warning,
  exceeded
  ;

  static BudgetState fromApi(String value) => switch (value) {
    'WARNING' => warning,
    'EXCEEDED' => exceeded,
    _ => ok,
  };
}

/// One budget's numbers for a period (`GET /budgets`). Amounts are paise.
@immutable
class BudgetStatus {
  const BudgetStatus({
    required this.id,
    required this.name,
    required this.kind,
    required this.color,
    required this.icon,
    required this.alertPercent,
    required this.categories,
    required this.amount,
    required this.budgeted,
    required this.hasOverride,
    required this.spent,
    required this.remaining,
    required this.percent,
    required this.state,
    required this.daysLeft,
    this.safeToSpendPerDay,
    this.rollover = false,
    this.rolloverIn = 0,
  });

  factory BudgetStatus.fromJson(Map<String, dynamic> json) => BudgetStatus(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: BudgetKind.fromApi(json['kind'] as String),
    color: parseHexColor(json['color'] as String),
    icon: json['icon'] as String,
    alertPercent: (json['alertPercent'] as num).toInt(),
    categories: [
      for (final c in (json['categories'] as List).cast<Map<String, dynamic>>()) CategoryRef.fromJson(c),
    ],
    amount: (json['amount'] as num).toInt(),
    budgeted: (json['budgeted'] as num).toInt(),
    hasOverride: json['hasOverride'] as bool? ?? false,
    spent: (json['spent'] as num).toInt(),
    remaining: (json['remaining'] as num).toInt(),
    percent: (json['percent'] as num).toInt(),
    state: BudgetState.fromApi(json['status'] as String),
    daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 0,
    safeToSpendPerDay: (json['safeToSpendPerDay'] as num?)?.toInt(),
    rollover: json['rollover'] as bool? ?? false,
    rolloverIn: (json['rolloverIn'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String name;
  final BudgetKind kind;
  final Color color;
  final String icon;
  final int alertPercent;
  final List<CategoryRef> categories;

  /// Default monthly amount.
  final int amount;

  /// Amount for this period (the override if one is set).
  final int budgeted;
  final bool hasOverride;
  final int spent;
  final int remaining;
  final int percent;
  final BudgetState state;
  final int daysLeft;
  final int? safeToSpendPerDay;

  /// Carry unspent money (or overspending) into the next month.
  final bool rollover;

  /// Carried in from earlier months: + unspent, − overspent.
  final int rolloverIn;

  /// What can be spent this period: the amount plus anything carried over.
  int get available => budgeted + rolloverIn;

  /// Spent / available, for rings and bars (may exceed 1).
  double get progress => available > 0 ? spent / available : (spent > 0 ? 1.0 : 0.0);
}

@immutable
class BudgetsOverview {
  const BudgetsOverview({
    required this.month,
    required this.periodStart,
    required this.periodEnd,
    required this.daysLeft,
    required this.budgets,
    required this.budgeted,
    required this.spent,
    required this.unbudgeted,
  });

  factory BudgetsOverview.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>;
    return BudgetsOverview(
      month: json['month'] as String,
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      daysLeft: (json['daysLeft'] as num).toInt(),
      budgets: [for (final b in (json['budgets'] as List).cast<Map<String, dynamic>>()) BudgetStatus.fromJson(b)],
      budgeted: (totals['budgeted'] as num).toInt(),
      spent: (totals['spent'] as num).toInt(),
      unbudgeted: (json['unbudgeted'] as num).toInt(),
    );
  }

  /// "YYYY-MM" of the period start.
  final String month;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int daysLeft;
  final List<BudgetStatus> budgets;
  final int budgeted;
  final int spent;

  /// Expenses in categories that belong to no budget.
  final int unbudgeted;

  int get remaining => budgeted - spent;
  double get progress => budgeted > 0 ? spent / budgeted : 0;
}

@immutable
class BudgetHistoryPoint {
  const BudgetHistoryPoint({required this.month, required this.spent, this.budgeted});

  factory BudgetHistoryPoint.fromJson(Map<String, dynamic> json) => BudgetHistoryPoint(
    month: json['month'] as String,
    spent: (json['spent'] as num).toInt(),
    budgeted: (json['budgeted'] as num?)?.toInt(),
  );

  final String month;
  final int spent;

  /// Null for periods before the budget existed.
  final int? budgeted;
}

@immutable
class BudgetDetail {
  const BudgetDetail({
    required this.status,
    required this.transactions,
    required this.history,
    required this.periodStart,
    required this.periodEnd,
  });

  factory BudgetDetail.fromJson(Map<String, dynamic> json) => BudgetDetail(
    status: BudgetStatus.fromJson(json),
    transactions: [
      for (final t in (json['transactions'] as List? ?? const []).cast<Map<String, dynamic>>()) Txn.fromJson(t),
    ],
    history: [
      for (final h in (json['history'] as List? ?? const []).cast<Map<String, dynamic>>())
        BudgetHistoryPoint.fromJson(h),
    ],
    periodStart: DateTime.parse(json['periodStart'] as String),
    periodEnd: DateTime.parse(json['periodEnd'] as String),
  );

  final BudgetStatus status;
  final List<Txn> transactions;
  final List<BudgetHistoryPoint> history;
  final DateTime periodStart;
  final DateTime periodEnd;
}

/// A budget that a new expense pushed past its alert level or limit.
@immutable
class BudgetAlert {
  const BudgetAlert({
    required this.budgetId,
    required this.name,
    required this.percent,
    required this.exceeded,
    required this.remaining,
  });

  factory BudgetAlert.fromJson(Map<String, dynamic> json) => BudgetAlert(
    budgetId: json['budgetId'] as String,
    name: json['name'] as String,
    percent: (json['percent'] as num).toInt(),
    exceeded: json['status'] == 'EXCEEDED',
    remaining: (json['remaining'] as num).toInt(),
  );

  final String budgetId;
  final String name;
  final int percent;
  final bool exceeded;
  final int remaining;
}
