import 'package:flutter/material.dart';
import 'package:hisaabchat/features/accounts/data/account.dart' show parseHexColor;

enum TxnType {
  expense('EXPENSE', 'Expense'),
  income('INCOME', 'Income'),
  transfer('TRANSFER', 'Transfer'),
  adjustment('ADJUSTMENT', 'Adjustment'),

  /// Lend & borrow: money between an account and a person.
  lend('LEND', 'Lent'),
  borrow('BORROW', 'Borrowed'),
  collect('COLLECT', 'Got back'),
  repay('REPAY', 'Paid back')
  ;

  const TxnType(this.api, this.label);

  final String api;
  final String label;

  bool get isPeople => this == lend || this == borrow || this == collect || this == repay;

  /// Positive when it makes the person owe you more (lend, repay).
  int get personSign => this == lend || this == repay ? 1 : -1;

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

@immutable
class PersonRef {
  const PersonRef({required this.id, required this.name, required this.color});

  factory PersonRef.fromJson(Map<String, dynamic> json) => PersonRef(
    id: json['id'] as String,
    name: json['name'] as String,
    color: parseHexColor(json['color'] as String),
  );

  final String id;
  final String name;
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
    this.person,
    this.dueDate,
    this.isRecurring = false,
    this.recurringRuleId,
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
    person: json['person'] == null ? null : PersonRef.fromJson(json['person'] as Map<String, dynamic>),
    dueDate: json['dueDate'] == null ? null : DateTime.parse(json['dueDate'] as String),
    isRecurring: json['isRecurring'] as bool? ?? false,
    recurringRuleId: json['recurringRuleId'] as String?,
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

  /// Lend & borrow entries: who, and (lend/borrow) when it should come back.
  final PersonRef? person;

  /// A calendar date (local midnight).
  final DateTime? dueDate;
  final bool isRecurring;
  final String? recurringRuleId;

  DateTime get localDate => date.toLocal();

  /// Money in or out for [accountId] (decides the bubble side and sign).
  TxnDirection directionFor(String accountId) => switch (type) {
    TxnType.income => TxnDirection.incoming,
    TxnType.expense => TxnDirection.outgoing,
    TxnType.transfer => toAccount?.id == accountId ? TxnDirection.incoming : TxnDirection.outgoing,
    TxnType.adjustment => adjustmentIncrease ?? false ? TxnDirection.incoming : TxnDirection.outgoing,
    TxnType.lend || TxnType.repay => TxnDirection.outgoing,
    TxnType.borrow || TxnType.collect => TxnDirection.incoming,
  };

  /// Signed paise for [accountId]: positive in, negative out.
  int signedFor(String accountId) => directionFor(accountId) == TxnDirection.incoming ? amount : -amount;

  /// Short label: category name, "To SBI"/"From Cash", or "Balance adjusted".
  String labelFor(String? accountId) => switch (type) {
    TxnType.transfer when accountId != null && toAccount?.id == accountId => 'From ${account.name}',
    TxnType.transfer when accountId != null => 'To ${toAccount?.name ?? 'account'}',
    TxnType.transfer => 'Transfer to ${toAccount?.name ?? 'account'}',
    TxnType.adjustment => 'Balance adjusted',
    TxnType.lend => 'Lent to ${person?.name ?? 'someone'}',
    TxnType.borrow => 'Borrowed from ${person?.name ?? 'someone'}',
    TxnType.collect => 'Got back from ${person?.name ?? 'someone'}',
    TxnType.repay => 'Paid back ${person?.name ?? 'someone'}',
    _ => category?.name ?? type.label,
  };

  /// In a person's thread: what happened, from your side ("You lent", "You got back").
  String get personLabel => switch (type) {
    TxnType.lend => 'You lent',
    TxnType.borrow => 'You borrowed',
    TxnType.collect => 'You got back',
    TxnType.repay => 'You paid back',
    _ => labelFor(null),
  };

  /// Body for POST /transactions that recreates this transaction (undo).
  Map<String, Object?> toCreateBody() => {
    'id': id,
    'type': type.api,
    'amount': amount,
    'accountId': account.id,
    'toAccountId': toAccount?.id,
    'categoryId': category?.id,
    'personId': person?.id,
    if (dueDate != null) 'dueDate': isoDateOf(dueDate!),
    'date': date.toIso8601String(),
    'note': note,
  };
}

/// "2026-10-31" for a local calendar date (the API's date-only format).
String isoDateOf(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
