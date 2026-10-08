import 'package:flutter/material.dart';

/// Account types (docs/01-PRD.md ACC-1) with their default look.
enum AccountType {
  cash('CASH', 'Cash', 'Cash', 'payments', Color(0xFF16A34A)),
  bank('BANK', 'Bank account', 'Bank', 'account_balance', Color(0xFF4F46E5)),
  wallet('WALLET', 'UPI / Wallet', 'UPI', 'smartphone', Color(0xFF0EA5E9)),
  creditCard('CREDIT_CARD', 'Credit card', 'Cards', 'credit_card', Color(0xFFF97316)),
  savings('SAVINGS', 'Savings', 'Savings', 'savings', Color(0xFF14B8A6)),
  other('OTHER', 'Other', 'Other', 'wallet', Color(0xFF64748B))
  ;

  const AccountType(this.api, this.label, this.shortLabel, this.defaultIcon, this.defaultColor);

  final String api;
  final String label;

  /// Filter-chip label.
  final String shortLabel;
  final String defaultIcon;
  final Color defaultColor;

  static AccountType fromApi(String value) =>
      values.firstWhere((type) => type.api == value, orElse: () => AccountType.other);
}

/// A money account (`GET /accounts`). Amounts are paise.
@immutable
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.balance,
    required this.color,
    required this.icon,
    required this.includeInTotal,
    required this.archived,
    this.creditLimit,
    this.lastTransaction,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    name: json['name'] as String,
    type: AccountType.fromApi(json['type'] as String),
    openingBalance: (json['openingBalance'] as num).toInt(),
    balance: (json['balance'] as num).toInt(),
    creditLimit: (json['creditLimit'] as num?)?.toInt(),
    color: parseHexColor(json['color'] as String),
    icon: json['icon'] as String,
    includeInTotal: json['includeInTotal'] as bool,
    archived: json['archived'] as bool? ?? false,
    lastTransaction: json['lastTransaction'] == null
        ? null
        : LastTxnPreview.fromJson(json['lastTransaction'] as Map<String, dynamic>),
  );

  final String id;
  final String name;
  final AccountType type;
  final int openingBalance;
  final int balance;
  final int? creditLimit;
  final Color color;
  final String icon;
  final bool includeInTotal;
  final bool archived;

  /// Newest transaction touching this account (the chat-list preview line).
  final LastTxnPreview? lastTransaction;

  bool get isCreditCard => type == AccountType.creditCard;

  /// Amount owed on a credit card (positive), or 0.
  int get outstanding => isCreditCard && balance < 0 ? -balance : 0;

  /// Credit still available on a card with a limit.
  int? get availableCredit => isCreditCard && creditLimit != null ? creditLimit! - outstanding : null;
}

Color parseHexColor(String hex) => Color(int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);

String toHexColor(Color color) => '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// "Last message" shown under an account in the list.
@immutable
class LastTxnPreview {
  const LastTxnPreview({
    required this.amount,
    required this.date,
    required this.incoming,
    required this.label,
    this.note,
  });

  factory LastTxnPreview.fromJson(Map<String, dynamic> json) => LastTxnPreview(
    amount: (json['amount'] as num).toInt(),
    date: DateTime.parse(json['date'] as String).toUtc(),
    incoming: json['direction'] == 'IN',
    label: json['label'] as String,
    note: json['note'] as String?,
  );

  final int amount;
  final DateTime date;
  final bool incoming;
  final String label;
  final String? note;
}
