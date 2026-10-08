import 'package:flutter/widgets.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';

/// Top-level sections. The order matches the StatefulShellRoute branches.
enum Destination {
  home('Home', AppIcons.home, '/dashboard'),
  transactions('Transactions', AppIcons.transactions, '/transactions'),
  budgets('Budgets', AppIcons.budgets, '/budgets'),
  accounts('Accounts', AppIcons.accounts, '/accounts'),
  people('People', AppIcons.people, '/people'),
  reports('Reports', AppIcons.reports, '/reports'),
  settings('Settings', AppIcons.settings, '/settings')
  ;

  const Destination(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;

  /// Tabs in the phone's bottom navigation bar (WhatsApp has four too).
  /// People, Reports and Settings live in the ⋮ menu on phones.
  static const List<Destination> bottomBar = [home, transactions, budgets, accounts];

  /// Sections in the top half of the desktop rail; Settings sits at the bottom.
  static const List<Destination> railTop = [home, transactions, budgets, accounts, people, reports];

  bool get isTab => bottomBar.contains(this);
}
