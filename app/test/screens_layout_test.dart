import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/app/router.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/auth/data/app_user.dart';

import 'helpers.dart';

// Every main screen, in light and dark mode, on a small phone, a large
// phone and a desktop window: nothing may overflow or throw.

FakeAuthRepository _userWith(ThemeMode theme) {
  final repo = FakeAuthRepository();
  final u = repo.user;
  repo.user = AppUser(
    id: u.id,
    email: u.email,
    fullName: u.fullName,
    initials: u.initials,
    currency: u.currency,
    timezone: u.timezone,
    monthStartDay: u.monthStartDay,
    theme: theme,
    accent: u.accent,
    onboardedAt: u.onboardedAt,
  );
  return repo;
}

FakeAccountsRepository _accounts() => FakeAccountsRepository([
  const Account(
    id: 'cash',
    name: 'Cash',
    type: AccountType.cash,
    openingBalance: 500000,
    balance: 500000,
    color: Color(0xFF16A34A),
    icon: 'payments',
    includeInTotal: true,
    archived: false,
  ),
  const Account(
    id: 'sbi',
    name: 'SBI Savings',
    type: AccountType.bank,
    openingBalance: 4200000,
    balance: 4200000,
    color: Color(0xFF2563EB),
    icon: 'account_balance',
    includeInTotal: true,
    archived: false,
  ),
  const Account(
    id: 'card',
    name: 'HDFC Card',
    type: AccountType.creditCard,
    openingBalance: -320000,
    balance: -320000,
    creditLimit: 10000000,
    color: Color(0xFF9333EA),
    icon: 'credit_card',
    includeInTotal: true,
    archived: false,
  ),
]);

Future<void> _seed(TestApp app) async {
  final now = DateTime.now();
  String at(int daysAgo, [int hour = 12]) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour).toUtc().toIso8601String();
  Future<void> budget(String name, int amount, String category) => app.budgets.create({
    'name': name,
    'amount': amount,
    'kind': 'VARIABLE',
    'categoryIds': [app.categories.byName(category).id],
  });
  await budget('Food & Groceries', 600000, 'Food & Groceries');
  await budget('Room Rent', 900000, 'Room Rent');
  await budget('Petrol', 200000, 'Petrol');
  app.budgets.budgets.first.carried = 45000;

  Future<void> txn(String type, int amount, String account, {String? category, String? note, int day = 0}) =>
      app.txns.create({
        'type': type,
        'amount': amount,
        'accountId': account,
        'categoryId': category == null ? null : app.categories.byName(category).id,
        'note': note,
        'date': at(day, 9 + day % 10),
      });
  await txn('INCOME', 4500000, 'sbi', category: 'Salary', note: 'October salary', day: 9);
  await txn('EXPENSE', 900000, 'sbi', category: 'Room Rent', note: 'Rent', day: 8);
  await txn('EXPENSE', 124050, 'cash', category: 'Food & Groceries', note: 'Big Bazaar', day: 3);
  await txn('EXPENSE', 45000, 'card', category: 'Eating Out', note: 'Pizza with Riya', day: 2);
  await txn('EXPENSE', 210000, 'card', category: 'Petrol', note: 'Full tank', day: 1);
  await txn('EXPENSE', 38000, 'cash', category: 'Food & Groceries', note: 'Vegetables');
  await app.txns.create({
    'type': 'TRANSFER',
    'amount': 200000,
    'accountId': 'sbi',
    'toAccountId': 'cash',
    'note': 'ATM',
    'date': at(4),
  });
  final amit = app.people.add('Amit');
  final riya = app.people.add('Riya');
  await app.txns.create({
    'type': 'LEND',
    'amount': 150000,
    'accountId': 'cash',
    'personId': amit,
    'note': 'Movie + dinner',
    'date': at(5),
  });
  await app.txns.create({'type': 'BORROW', 'amount': 50000, 'accountId': 'cash', 'personId': riya, 'date': at(6)});
}

/// Main screens by path.
const _screens = [
  '/dashboard',
  '/transactions',
  '/budgets',
  '/budgets/summary',
  '/accounts',
  '/accounts/card',
  '/accounts/sbi/info',
  '/people',
  '/reports',
  '/settings',
  '/settings/profile',
  '/settings/appearance',
  '/settings/data',
  '/settings/recurring',
  '/settings/categories',
  '/settings/connection',
  '/search',
];

Future<void> _go(WidgetTester tester, String path) async {
  final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  container.read(routerProvider).go(path);
  await tester.pumpAndSettle();
}

void main() {
  const sizes = {'small phone': Size(360, 740), 'phone': Size(412, 915), 'desktop': Size(1280, 800)};
  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    for (final MapEntry(key: label, value: size) in sizes.entries) {
      testWidgets('${theme.name} · $label: every screen lays out', (tester) async {
        await pumpApp(
          tester,
          savedToken: 'oat',
          repo: _userWith(theme),
          accounts: _accounts(),
          seed: _seed,
          size: size,
        );
        await tester.pumpAndSettle();
        final brightness = theme == ThemeMode.dark ? Brightness.dark : Brightness.light;
        expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, brightness);

        for (final path in _screens) {
          await _go(tester, path);
          expect(tester.takeException(), isNull, reason: path);
        }

        // A person's chat and the new-transaction form.
        await _go(tester, '/people');
        await tester.tap(find.text('Amit').first);
        await tester.pumpAndSettle();
        await _go(tester, '/transactions');
        await tester.tap(find.byTooltip('New transaction').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
