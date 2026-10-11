import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/presentation/account_tile.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_widgets.dart';
import 'package:hisaabchat/features/people/presentation/people_widgets.dart';
import 'package:hisaabchat/features/people/presentation/person_thread.dart';
import 'package:hisaabchat/features/search/search_screen.dart';
import 'package:hisaabchat/features/transactions/presentation/transactions_section.dart';
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';

import 'helpers.dart';

Account _account(String id, String name, AccountType type) => Account(
  id: id,
  name: name,
  type: type,
  openingBalance: 1000000,
  balance: 1000000,
  color: type.defaultColor,
  icon: type.defaultIcon,
  includeInTotal: true,
  archived: false,
);

FakeAccountsRepository _accounts() => FakeAccountsRepository([
  _account('cash', 'Cash', AccountType.cash),
  _account('bank', 'SBI Savings', AccountType.bank),
]);

/// Petrol ₹120 from Cash ("Shell pump"), groceries ₹540 from SBI, Amit, a Bike budget.
Future<void> _seed(TestApp app) async {
  final now = DateTime.now().toUtc();
  await app.txns.create({
    'type': 'EXPENSE',
    'amount': 12000,
    'accountId': 'cash',
    'categoryId': app.categories.byName('Petrol').id,
    'note': 'Shell pump',
    'date': now.toIso8601String(),
  });
  await app.txns.create({
    'type': 'EXPENSE',
    'amount': 54000,
    'accountId': 'bank',
    'categoryId': app.categories.byName('Food & Groceries').id,
    'date': now.subtract(const Duration(hours: 1)).toIso8601String(),
  });
  app.people.add('Amit');
  await app.budgets.create({
    'name': 'Bike',
    'amount': 500000,
    'kind': 'VARIABLE',
    'categoryIds': [app.categories.byName('Petrol').id],
  });
}

Finder _searchField() => find.descendant(of: find.byType(SearchScreen), matching: find.byType(TextField));

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(_searchField(), text);
  await tester.pump(const Duration(milliseconds: 300)); // debounce
  await tester.pumpAndSettle();
}

Finder _inResults(Finder finder) => find.descendant(of: find.byType(SearchScreen), matching: finder);

void main() {
  testWidgets('the search icon opens search; it finds accounts, people, budgets and transactions', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _accounts(), seed: _seed);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Search HisaabChat'), findsOneWidget);

    // An account name finds the account and its transactions.
    await _search(tester, 'sbi');
    expect(_inResults(find.widgetWithText(AccountTile, 'SBI Savings')), findsOneWidget);
    expect(_inResults(find.widgetWithText(TransactionTile, 'Food & Groceries')), findsOneWidget);

    // A category finds the budget it belongs to and its transactions.
    await _search(tester, 'petrol');
    expect(_inResults(find.widgetWithText(BudgetTile, 'Bike')), findsOneWidget);
    expect(_inResults(find.widgetWithText(TransactionTile, 'Petrol')), findsOneWidget);

    // An amount as typed.
    await _search(tester, '540');
    expect(_inResults(find.widgetWithText(TransactionTile, 'Food & Groceries')), findsOneWidget);
    expect(_inResults(find.widgetWithText(TransactionTile, 'Petrol')), findsNothing);

    // A person.
    await _search(tester, 'ami');
    expect(_inResults(find.widgetWithText(PersonTile, 'Amit')), findsOneWidget);

    // Nothing.
    await _search(tester, 'zzz');
    expect(find.text('No results for “zzz”'), findsOneWidget);
  });

  testWidgets('results open, and Back returns to the results', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _accounts(), seed: _seed);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await _search(tester, 'shell');
    await tester.tap(_inResults(find.widgetWithText(TransactionTile, 'Petrol')));
    await tester.pumpAndSettle();
    expect(find.byType(TxnForm), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TxnForm), findsNothing);
    expect(find.byType(SearchScreen), findsOneWidget);

    await _search(tester, 'amit');
    await tester.tap(_inResults(find.widgetWithText(PersonTile, 'Amit')));
    await tester.pumpAndSettle();
    expect(find.byType(PersonThreadScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('amit'), findsOneWidget); // what was typed is still there
  });

  testWidgets('desktop: Ctrl+F and the rail button open search', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _accounts(), seed: _seed, size: const Size(1280, 800));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);

    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('Budgets search matches names and categories; ✕ clears it', (tester) async {
    await pumpApp(
      tester,
      savedToken: 'oat',
      accounts: _accounts(),
      seed: (a) async {
        await _seed(a);
        await a.budgets.create({
          'name': 'Room Rent',
          'amount': 900000,
          'kind': 'FIXED',
          'categoryIds': [a.categories.byName('Room Rent').id],
        });
      },
    );
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Budgets')));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetTile), findsNWidgets(2));

    await tester.enterText(find.widgetWithText(TextField, 'Search budgets'), 'petrol');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(BudgetTile, 'Bike'), findsOneWidget);
    expect(find.widgetWithText(BudgetTile, 'Room Rent'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetTile), findsNWidgets(2));
  });

  testWidgets('Transactions tab search finds an account name', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _accounts(), seed: _seed);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Transactions')));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Search transactions'), 'cash');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TransactionTile, 'Petrol'), findsOneWidget);
    expect(find.widgetWithText(TransactionTile, 'Food & Groceries'), findsNothing);
  });

  testWidgets('Settings → Categories search', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _accounts());
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Search categories').first, 'bike');
    await tester.pumpAndSettle();
    expect(find.text('Bike EMI'), findsOneWidget);
    expect(find.text('Petrol'), findsNothing);
  });
}
