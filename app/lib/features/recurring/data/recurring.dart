import 'package:flutter/material.dart';
import 'package:hisaabchat/features/accounts/data/account.dart' show parseHexColor;
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:intl/intl.dart';

enum Frequency {
  daily('DAILY', 'Daily', 'day'),
  weekly('WEEKLY', 'Weekly', 'week'),
  monthly('MONTHLY', 'Monthly', 'month'),
  yearly('YEARLY', 'Yearly', 'year')
  ;

  const Frequency(this.api, this.label, this.unit);

  final String api;
  final String label;
  final String unit;

  static Frequency fromApi(String value) => values.firstWhere((f) => f.api == value, orElse: () => monthly);
}

/// Parses an API calendar date ("2026-10-31") as a local date.
DateTime parseLocalDate(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

/// "1st", "2nd", "23rd"…
String ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}

/// A repeating transaction template (`RecurringRuleDTO`).
@immutable
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.type,
    required this.amount,
    required this.account,
    required this.frequency,
    required this.interval,
    required this.startDate,
    required this.autoCreate,
    required this.isActive,
    this.toAccount,
    this.category,
    this.note,
    this.dayOfMonth,
    this.endDate,
    this.nextDate,
  });

  factory RecurringRule.fromJson(Map<String, dynamic> json) => RecurringRule(
    id: json['id'] as String,
    type: TxnType.fromApi(json['type'] as String),
    amount: (json['amount'] as num).toInt(),
    account: AccountRef.fromJson(json['account'] as Map<String, dynamic>),
    toAccount: json['toAccount'] == null ? null : AccountRef.fromJson(json['toAccount'] as Map<String, dynamic>),
    category: json['category'] == null ? null : CategoryRef.fromJson(json['category'] as Map<String, dynamic>),
    note: json['note'] as String?,
    frequency: Frequency.fromApi(json['frequency'] as String),
    interval: (json['interval'] as num?)?.toInt() ?? 1,
    dayOfMonth: (json['dayOfMonth'] as num?)?.toInt(),
    startDate: parseLocalDate(json['startDate'] as String),
    endDate: json['endDate'] == null ? null : parseLocalDate(json['endDate'] as String),
    autoCreate: json['autoCreate'] as bool? ?? false,
    isActive: json['isActive'] as bool? ?? true,
    nextDate: json['nextDate'] == null ? null : parseLocalDate(json['nextDate'] as String),
  );

  final String id;
  final TxnType type;
  final int amount;
  final AccountRef account;
  final AccountRef? toAccount;
  final CategoryRef? category;
  final String? note;
  final Frequency frequency;
  final int interval;
  final int? dayOfMonth;
  final DateTime startDate;
  final DateTime? endDate;

  /// true = added automatically on the due date; false = waits for Confirm.
  final bool autoCreate;
  final bool isActive;
  final DateTime? nextDate;

  /// "Bike EMI", "Transfer to SBI", or the note.
  String get title => switch (type) {
    TxnType.transfer => 'Transfer to ${toAccount?.name ?? 'account'}',
    _ => category?.name ?? note ?? type.label,
  };

  /// "Monthly on the 5th", "Every 2 weeks", "Yearly on 12 Mar".
  String get scheduleLabel {
    final every = interval == 1 ? frequency.label : 'Every $interval ${frequency.unit}s';
    return switch (frequency) {
      Frequency.monthly => '$every on the ${ordinal(dayOfMonth ?? startDate.day)}',
      Frequency.weekly => '$every on ${DateFormat.EEEE().format(startDate)}',
      Frequency.yearly => '$every on ${DateFormat('d MMM').format(startDate)}',
      Frequency.daily => every,
    };
  }

  IconData icon(IconData Function(String key) byKey, IconData transferIcon) =>
      type == TxnType.transfer ? transferIcon : byKey(category?.icon ?? 'category');

  Color colorOr(Color fallback) => category?.color ?? fallback;
}

/// A due date waiting for Confirm or Skip (remind-me rules).
@immutable
class PendingOccurrence {
  const PendingOccurrence({required this.id, required this.dueDate, required this.rule});

  factory PendingOccurrence.fromJson(Map<String, dynamic> json) => PendingOccurrence(
    id: json['id'] as String,
    dueDate: parseLocalDate(json['dueDate'] as String),
    rule: RecurringRule.fromJson(json['rule'] as Map<String, dynamic>),
  );

  final String id;
  final DateTime dueDate;
  final RecurringRule rule;
}

/// Money someone should give back (or you should pay back) by a date.
@immutable
class PersonDue {
  const PersonDue({
    required this.transactionId,
    required this.lent,
    required this.dueDate,
    required this.amount,
    required this.personId,
    required this.personName,
    required this.personColor,
  });

  factory PersonDue.fromJson(Map<String, dynamic> json) {
    final person = json['person'] as Map<String, dynamic>;
    return PersonDue(
      transactionId: json['transactionId'] as String,
      lent: json['type'] == 'LEND',
      dueDate: parseLocalDate(json['dueDate'] as String),
      amount: (json['amount'] as num).toInt(),
      personId: person['id'] as String,
      personName: person['name'] as String,
      personColor: parseHexColor(person['color'] as String),
    );
  }

  final String transactionId;

  /// true = they should pay you back; false = you should pay them back.
  final bool lent;
  final DateTime dueDate;
  final int amount;
  final String personId;
  final String personName;
  final Color personColor;
}

/// `GET /recurring/upcoming`.
@immutable
class Upcoming {
  const Upcoming({required this.today, required this.pending, required this.upcoming, required this.dues});

  factory Upcoming.fromJson(Map<String, dynamic> json) => Upcoming(
    today: parseLocalDate(json['today'] as String),
    pending: [
      for (final p in (json['pending'] as List).cast<Map<String, dynamic>>()) PendingOccurrence.fromJson(p),
    ],
    upcoming: [
      for (final u in (json['upcoming'] as List).cast<Map<String, dynamic>>())
        (date: parseLocalDate(u['date'] as String), rule: RecurringRule.fromJson(u['rule'] as Map<String, dynamic>)),
    ],
    dues: [for (final d in (json['dues'] as List).cast<Map<String, dynamic>>()) PersonDue.fromJson(d)],
  );

  static final empty = Upcoming(today: DateTime(2000), pending: const [], upcoming: const [], dues: const []);

  final DateTime today;
  final List<PendingOccurrence> pending;
  final List<({DateTime date, RecurringRule rule})> upcoming;
  final List<PersonDue> dues;

  int get count => pending.length + upcoming.length + dues.length;
  bool get isEmpty => count == 0;
}

/// "today", "tomorrow", "in 3 days", "2 days ago".
String dueLabel(DateTime date, DateTime today) {
  final days = DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
  return switch (days) {
    0 => 'today',
    1 => 'tomorrow',
    -1 => 'yesterday',
    > 1 => 'in $days days',
    _ => '${-days} days ago',
  };
}
