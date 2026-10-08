import 'package:flutter/material.dart';
import 'package:hisaabchat/features/accounts/data/account.dart' show parseHexColor;
import 'package:hisaabchat/features/budgets/data/budget.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';

/// Home dashboard (`GET /dashboard`). Amounts are paise.
@immutable
class Dashboard {
  const Dashboard({
    required this.month,
    required this.periodStart,
    required this.periodEnd,
    required this.netWorth,
    required this.accountsCount,
    required this.income,
    required this.expense,
    required this.budgets,
    required this.budgeted,
    required this.spent,
    required this.recent,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    final totals = json['budgetTotals'] as Map<String, dynamic>? ?? const {};
    return Dashboard(
      month: json['month'] as String,
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      netWorth: (json['netWorth'] as num).toInt(),
      accountsCount: (json['accountsCount'] as num).toInt(),
      income: (json['income'] as num).toInt(),
      expense: (json['expense'] as num).toInt(),
      budgets: [for (final b in (json['budgets'] as List).cast<Map<String, dynamic>>()) BudgetStatus.fromJson(b)],
      budgeted: (totals['budgeted'] as num?)?.toInt() ?? 0,
      spent: (totals['spent'] as num?)?.toInt() ?? 0,
      recent: [for (final t in (json['recent'] as List).cast<Map<String, dynamic>>()) Txn.fromJson(t)],
    );
  }

  final String month;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int netWorth;
  final int accountsCount;
  final int income;
  final int expense;
  final List<BudgetStatus> budgets;
  final int budgeted;
  final int spent;
  final List<Txn> recent;

  int get net => income - expense;
}

/// One row of the spending (or income) by category report.
@immutable
class CategorySpend {
  const CategorySpend({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.total,
    required this.count,
    required this.percent,
  });

  factory CategorySpend.fromJson(Map<String, dynamic> json) => CategorySpend(
    categoryId: json['categoryId'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
    color: parseHexColor(json['color'] as String),
    total: (json['total'] as num).toInt(),
    count: (json['count'] as num).toInt(),
    percent: (json['percent'] as num).toDouble(),
  );

  final String categoryId;
  final String name;
  final String icon;
  final Color color;
  final int total;
  final int count;

  /// Share of the period total, 0–100 with one decimal.
  final double percent;
}

/// `GET /reports/categories`.
@immutable
class CategoryReport {
  const CategoryReport({
    required this.month,
    required this.periodStart,
    required this.periodEnd,
    required this.from,
    required this.to,
    required this.type,
    required this.total,
    required this.items,
  });

  factory CategoryReport.fromJson(Map<String, dynamic> json) => CategoryReport(
    month: json['month'] as String,
    periodStart: DateTime.parse(json['periodStart'] as String),
    periodEnd: DateTime.parse(json['periodEnd'] as String),
    from: DateTime.parse(json['from'] as String),
    to: DateTime.parse(json['to'] as String),
    type: TxnType.fromApi(json['type'] as String),
    total: (json['total'] as num).toInt(),
    items: [for (final i in (json['items'] as List).cast<Map<String, dynamic>>()) CategorySpend.fromJson(i)],
  );

  final String month;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Exact period bounds (UTC), for listing the transactions behind a row.
  final DateTime from;
  final DateTime to;
  final TxnType type;
  final int total;
  final List<CategorySpend> items;
}

/// One month of `GET /reports/trend`.
@immutable
class TrendPoint {
  const TrendPoint({
    required this.month,
    required this.income,
    required this.expense,
  });

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
    month: json['month'] as String,
    income: (json['income'] as num).toInt(),
    expense: (json['expense'] as num).toInt(),
  );

  final String month;
  final int income;
  final int expense;

  int get net => income - expense;
}
