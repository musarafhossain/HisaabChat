import 'package:flutter/material.dart';
import 'package:hisaabchat/features/accounts/data/account.dart' show parseHexColor;

/// Someone you lend money to or borrow from (`PersonDTO`).
@immutable
class Person {
  const Person({
    required this.id,
    required this.name,
    required this.color,
    required this.balance,
    this.phone,
    this.note,
    this.archived = false,
    this.lastActivity,
  });

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    note: json['note'] as String?,
    color: parseHexColor(json['color'] as String),
    archived: json['archived'] as bool? ?? false,
    balance: (json['balance'] as num).toInt(),
    lastActivity: json['lastActivity'] == null ? null : DateTime.parse(json['lastActivity'] as String),
  );

  final String id;
  final String name;
  final String? phone;
  final String? note;
  final Color color;
  final bool archived;

  /// Paise. Positive = they owe you; negative = you owe them.
  final int balance;
  final DateTime? lastActivity;

  bool get settled => balance == 0;

  /// "AK" from "Amit Kumar".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

/// `GET /people`: everyone plus the Home card totals.
@immutable
class PeopleState {
  const PeopleState({required this.people, required this.youGet, required this.youOwe});

  final List<Person> people;

  /// Paise others owe you, and you owe others.
  final int youGet;
  final int youOwe;

  List<Person> get active => people.where((p) => !p.archived).toList();
  List<Person> get archived => people.where((p) => p.archived).toList();

  Person? byId(String? id) => people.where((p) => p.id == id).firstOrNull;
}
