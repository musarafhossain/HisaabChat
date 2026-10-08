import 'package:flutter/material.dart';
import 'package:hisaabchat/features/accounts/data/account.dart' show parseHexColor;

enum CategoryType {
  expense('EXPENSE'),
  income('INCOME')
  ;

  const CategoryType(this.api);

  final String api;

  static CategoryType fromApi(String value) => value == 'INCOME' ? income : expense;
}

/// A spending or income category (`GET /categories`).
@immutable
class TxnCategory {
  const TxnCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
    required this.sortOrder,
    this.isDefault = false,
    this.archived = false,
    this.parentId,
    this.budgetId,
  });

  factory TxnCategory.fromJson(Map<String, dynamic> json) => TxnCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    type: CategoryType.fromApi(json['type'] as String),
    color: parseHexColor(json['color'] as String),
    icon: json['icon'] as String,
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    isDefault: json['isDefault'] as bool? ?? false,
    archived: json['archived'] as bool? ?? false,
    parentId: json['parentId'] as String?,
    budgetId: json['budgetId'] as String?,
  );

  final String id;
  final String name;
  final CategoryType type;
  final Color color;
  final String icon;
  final int sortOrder;
  final bool isDefault;
  final bool archived;
  final String? parentId;
  final String? budgetId;
}
