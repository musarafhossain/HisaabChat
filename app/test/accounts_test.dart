import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/presentation/account_form.dart';
import 'package:hisaabchat/features/accounts/presentation/account_tile.dart';
import 'package:hisaabchat/features/accounts/presentation/accounts_section.dart';

import 'helpers.dart';

Finder _inAccounts(Finder finder) => find.descendant(of: find.byType(AccountsSection), matching: finder);
Finder _inForm(Finder finder) => find.descendant(of: find.byType(AccountForm), matching: finder);

/// Scrolls the form's submit button into view (it can sit below the fold on phones) and taps it.
Future<void> _submitForm(WidgetTester tester, String label) async {
  final button = _inForm(find.text(label));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Account _account(String id, String name, AccountType type, int balance, {bool includeInTotal = true}) => Account(
  id: id,
  name: name,
  type: type,
  openingBalance: balance,
  balance: balance,
  color: type.defaultColor,
  icon: type.defaultIcon,
  includeInTotal: includeInTotal,
  archived: false,
);

Future<void> _openAccountsTab(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Accounts')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add the first account from the empty state', (tester) async {
    await pumpApp(tester, savedToken: 'oat_saved');
    await _openAccountsTab(tester);

    expect(find.text('No accounts yet'), findsOneWidget);
    await tester.tap(_inAccounts(find.text('Add account')));
    await tester.pumpAndSettle();

    expect(find.text('New account'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Cash'), 'Cash');
    await tester.enterText(find.widgetWithText(TextFormField, '0'), '2300');
    await _submitForm(tester, 'Add account');

    expect(find.text('New account'), findsNothing);
    expect(find.widgetWithText(AccountTile, 'Cash'), findsWidgets);
    expect(_inAccounts(find.text('₹2,300')), findsNWidgets(2)); // tile + total
    expect(_inAccounts(find.text('1 account')), findsOneWidget);
  });

  testWidgets('a credit card counts its outstanding amount against the total', (tester) async {
    final accounts = FakeAccountsRepository([_account('a1', 'Cash', AccountType.cash, 500000)]);
    final app = await pumpApp(tester, savedToken: 'oat_saved', accounts: accounts);
    await _openAccountsTab(tester);

    await tester.tap(find.byTooltip('New account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Credit card'));
    await tester.pumpAndSettle();
    expect(find.text('Amount outstanding now'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. HDFC Card'), 'HDFC Card');
    await tester.enterText(find.widgetWithText(TextFormField, '0'), '1200');
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. 100000'), '100000');
    await _submitForm(tester, 'Add account');

    final card = app.accounts.accounts.last;
    expect(card.balance, -120000);
    expect(card.creditLimit, 10000000);
    expect(find.text('Outstanding'), findsOneWidget);
    expect(_inAccounts(find.text('₹3,800')), findsOneWidget); // 5,000 − 1,200
  });

  testWidgets('duplicate names show the server error on the field', (tester) async {
    final accounts = FakeAccountsRepository([_account('a1', 'Cash', AccountType.cash, 0)]);
    await pumpApp(tester, savedToken: 'oat_saved', accounts: accounts);
    await _openAccountsTab(tester);

    await tester.tap(find.byTooltip('New account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Cash'), 'cash');
    await _submitForm(tester, 'Add account');

    expect(find.text('You already have an account with this name'), findsOneWidget);
  });

  testWidgets('search and type chips filter the list', (tester) async {
    final accounts = FakeAccountsRepository([
      _account('a1', 'Cash', AccountType.cash, 230000),
      _account('a2', 'SBI Savings', AccountType.bank, 4095000),
      _account('a3', 'Paytm', AccountType.wallet, 50000),
    ]);
    await pumpApp(tester, savedToken: 'oat_saved', accounts: accounts);
    await _openAccountsTab(tester);

    expect(_inAccounts(find.text('₹43,750')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Bank'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AccountTile, 'SBI Savings'), findsOneWidget);
    expect(find.widgetWithText(AccountTile, 'Paytm'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search accounts'), 'pay');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AccountTile, 'Paytm'), findsOneWidget);
    expect(find.widgetWithText(AccountTile, 'Cash'), findsNothing);
  });

  testWidgets('phone: open an account, archive it, and it leaves the total', (tester) async {
    final accounts = FakeAccountsRepository([
      _account('a1', 'Cash', AccountType.cash, 100000),
      _account('a2', 'Old Wallet', AccountType.wallet, 20000),
    ]);
    await pumpApp(tester, savedToken: 'oat_saved', accounts: accounts);
    await _openAccountsTab(tester);
    expect(_inAccounts(find.text('₹1,200')), findsOneWidget);

    await tester.tap(find.widgetWithText(AccountTile, 'Old Wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Archive account'), findsOneWidget);

    await tester.tap(find.text('Archive account'));
    await tester.pumpAndSettle();
    expect(find.text('Unarchive account'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_inAccounts(find.text('₹1,000')), findsNWidgets(2)); // Cash tile + total
    expect(_inAccounts(find.text('Archived (1)')), findsOneWidget);
  });

  testWidgets('deleting an account with transactions explains why it failed', (tester) async {
    final accounts = FakeAccountsRepository([_account('a1', 'Cash', AccountType.cash, 100000)])..usedIds.add('a1');
    await pumpApp(tester, savedToken: 'oat_saved', accounts: accounts, size: const Size(1400, 900));

    await tester.tap(find.byTooltip('Accounts'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AccountTile, 'Cash').first);
    await tester.pumpAndSettle();

    // Desktop: the info opens in the detail pane, next to the list.
    expect(find.text('Delete account'), findsOneWidget);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('This account has transactions. Archive it instead.'), findsOneWidget);
    expect(accounts.accounts, hasLength(1));
  });

  testWidgets('Home shows the total balance once accounts exist', (tester) async {
    final accounts = FakeAccountsRepository([
      _account('a1', 'Cash', AccountType.cash, 230000),
      _account('a2', 'Emergency', AccountType.savings, 5000000, includeInTotal: false),
    ]);
    await pumpApp(tester, savedToken: 'oat_saved', accounts: accounts);

    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('₹2,300'), findsOneWidget);
    expect(find.text('Across 2 accounts'), findsOneWidget);
  });
}
