import 'package:flutter/material.dart';
import 'package:hisaabchat/features/accounts/data/account.dart' show parseHexColor;

enum TxnType {
  expense('EXPENSE', 'Expense'),
  income('INCOME', 'Income'),
  transfer('TRANSFER', 'Transfer'),
  adjustment('ADJUSTMENT', 'Adjustment')
  ;

  const TxnType(this.api, this.label);

  final String api;
  final String label;

  static TxnType fromApi(String value) => values.firstWhere((t) => t.api == value, orElse: () => expense);
}

/// Which way money moved, seen from one account (bubble side in a thread).
enum TxnDirection { incoming, outgoing }

@immutable
class AccountRef {
  const AccountRef({required this.id, required this.name, required this.icon, required this.color});

  factory AccountRef.fromJson(Map<String, dynamic> json) => AccountRef(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
    color: parseHexColor(json['color'] as String),
  );

  final String id;
  final String name;
  final String icon;
  final Color color;
}

@immutable
class CategoryRef {
  const CategoryRef({required this.id, required this.name, required this.icon, required this.color});

  factory CategoryRef.fromJson(Map<String, dynamic> json) => CategoryRef(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
    color: parseHexColor(json['color'] as String),
  );

  final String id;
  final String name;
  final String icon;
  final Color color;
}

/// A transaction (`TransactionDTO`). Amounts are paise; `date` is UTC.
@immutable
class Txn {
  const Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.account,
    this.note,
    this.toAccount,
    this.category,
    this.adjustmentIncrease,
    this.isRecurring = false,
  });

  factory Txn.fromJson(Map<String, dynamic> json) => Txn(
    id: json['id'] as String,
    type: TxnType.fromApi(json['type'] as String),
    amount: (json['amount'] as num).toInt(),
    date: DateTime.parse(json['date'] as String).toUtc(),
    note: json['note'] as String?,
    account: AccountRef.fromJson(json['account'] as Map<String, dynamic>),
    toAccount: json['toAccount'] == null ? null : AccountRef.fromJson(json['toAccount'] as Map<String, dynamic>),
    category: json['category'] == null ? null : CategoryRef.fromJson(json['category'] as Map<String, dynamic>),
    adjustmentIncrease: switch (json['adjustmentDirection']) {
      'INCREASE' => true,
      'DECREASE' => false,
      _ => null,
    },
    isRecurring: json['isRecurring'] as bool? ?? false,
  );

  final String id;
  final TxnType type;
  final int amount;
  final DateTime date;
  final String? note;
  final AccountRef account;
  final AccountRef? toAccount;
  final CategoryRef? category;

  /// For adjustments: true = balance went up.
  final bool? adjustmentIncrease;
  final bool isRecurring;

  DateTime get localDate => date.toLocal();

  /// Money in or out for [accountId] (decides the bubble side and sign).
  TxnDirection directionFor(String accountId) => switch (type) {
    TxnType.income => TxnDirection.incoming,
    TxnType.expense => TxnDirection.outgoing,
    TxnType.transfer => toAccount?.id == accountId ? TxnDirection.incoming : TxnDirection.outgoing,
    TxnType.adjustment => adjustmentIncrease ?? false ? TxnDirection.incoming : TxnDirection.outgoing,
  };

  /// Signed paise for [accountId]: positive in, negative out.
  int signedFor(String accountId) => directionFor(accountId) == TxnDirection.incoming ? amount : -amount;

  /// Short label: category name, "To SBI"/"From Cash", or "Balance adjusted".
  String labelFor(String? accountId) => switch (type) {
    TxnType.transfer when accountId != null && toAccount?.id == accountId => 'From ${account.name}',
    TxnType.transfer when accountId != null => 'To ${toAccount?.name ?? 'account'}',
    TxnType.transfer => 'Transfer to ${toAccount?.name ?? 'account'}',
    TxnType.adjustment => 'Balance adjusted',
    _ => category?.name ?? type.label,
  };

  /// Body for POST /transactions that recreates this transaction (undo).
  Map<String, Object?> toCreateBody() => {
    'id': id,
    'type': type.api,
    'amount': amount,
    'accountId': account.id,
    'toAccountId': toAccount?.id,
    'categoryId': category?.id,
    'date': date.toIso8601String(),
    'note': note,
  };
}

@immutable
class TxnTotals {
  const TxnTotals({this.income = 0, this.expense = 0, this.count = 0});

  factory TxnTotals.fromJson(Map<String, dynamic>? json) => TxnTotals(
    income: (json?['income'] as num?)?.toInt() ?? 0,
    expense: (json?['expense'] as num?)?.toInt() ?? 0,
    count: (json?['count'] as num?)?.toInt() ?? 0,
  );

  final int income;
  final int expense;
  final int count;
}

typedef TxnPage = ({List<Txn> items, String? nextCursor, TxnTotals totals});
