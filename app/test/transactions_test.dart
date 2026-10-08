import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/presentation/account_tile.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:hisaabchat/features/transactions/presentation/account_thread.dart';
import 'package:hisaabchat/features/transactions/presentation/quick_composer.dart';
import 'package:hisaabchat/features/transactions/presentation/thread_widgets.dart';
import 'package:hisaabchat/features/transactions/presentation/transactions_section.dart';
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';

import 'helpers.dart';

Account _account(String id, String name, AccountType type, int balance) => Account(
  id: id,
  name: name,
  type: type,
  openingBalance: balance,
  balance: balance,
  color: type.defaultColor,
  icon: type.defaultIcon,
  includeInTotal: true,
  archived: false,
);

FakeAccountsRepository _twoAccounts() => FakeAccountsRepository([
  _account('cash', 'Cash', AccountType.cash, 230000),
  _account('bank', 'SBI Savings', AccountType.bank, 4000000),
]);

Finder _composerField() => find.descendant(of: find.byType(QuickComposer), matching: find.byType(TextField));
Finder _inThread(Finder finder) => find.descendant(of: find.byType(AccountThread), matching: finder);
Finder _inForm(Finder finder) => find.descendant(of: find.byType(TxnForm), matching: finder);

Future<void> _openCashThread(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Accounts')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(AccountTile, 'Cash').first);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_composerField(), text);
  await tester.pumpAndSettle();
}

Future<void> _send(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Send'));
  await tester.pumpAndSettle();
}

Future<void> _tapInForm(WidgetTester tester, String label) async {
  final button = _inForm(find.text(label));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('quick add: "120 petrol" becomes an outgoing bubble and moves the balance', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _twoAccounts());
    await _openCashThread(tester);

    expect(_inThread(find.text('Balance ₹2,300')), findsOneWidget);
    expect(_inThread(find.text('Account opened with ₹2,300')), findsOneWidget);

    await _type(tester, '120 petrol');
    // The parser picked Petrol; it shows as the selected suggestion.
    final petrolChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Petrol'));
    expect(petrolChip.selected, isTrue);

    await _send(tester);

    expect(find.byType(TxnBubble), findsOneWidget);
    expect(_inThread(find.text('−₹120')), findsOneWidget);
    expect(_inThread(find.text('Balance ₹2,180')), findsOneWidget);
    expect(app.txns.txns.single.category?.name, 'Petrol');
    expect(app.txns.txns.single.note, isNull);
    // Outgoing bubbles sit on the right.
    expect(tester.getCenter(_inThread(find.text('−₹120'))).dx, greaterThan(200));
  });

  testWidgets('unknown words: pick a category before sending, the words become the note', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _twoAccounts());
    await _openCashThread(tester);

    await _type(tester, '250 birthday cake');
    await _send(tester);
    expect(find.text('Pick a category above'), findsOneWidget);
    expect(app.txns.txns, isEmpty);

    final eatingOut = find.widgetWithText(ChoiceChip, 'Eating Out', skipOffstage: false);
    await tester.ensureVisible(eatingOut);
    await tester.pumpAndSettle();
    await tester.tap(eatingOut);
    await tester.pumpAndSettle();
    await _send(tester);

    expect(app.txns.txns.single.note, 'birthday cake');
    expect(_inThread(find.text('birthday cake')), findsOneWidget);
  });

  testWidgets('income toggle sends money in (left side, green plus)', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _twoAccounts());
    await _openCashThread(tester);

    await tester.tap(find.byTooltip('Expense (tap for income)'));
    await tester.pumpAndSettle();
    await _type(tester, '35000 salary');
    await _send(tester);

    expect(app.txns.txns.single.type, TxnType.income);
    expect(_inThread(find.text('+₹35,000')), findsOneWidget);
    expect(_inThread(find.text('Balance ₹37,300')), findsOneWidget);
    expect(tester.getCenter(_inThread(find.text('+₹35,000'))).dx, lessThan(200));
  });

  testWidgets('a failed send shows "Not saved" and saves on tap', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _twoAccounts());
    app.txns.failNextCreates = 1;
    await _openCashThread(tester);

    await _type(tester, '60 chai');
    await _send(tester);
    expect(find.text('Not saved · Tap to retry'), findsOneWidget);
    expect(app.txns.txns, isEmpty);

    await tester.tap(find.text('Not saved · Tap to retry'));
    await tester.pumpAndSettle();
    expect(find.text('Not saved · Tap to retry'), findsNothing);
    expect(app.txns.txns, hasLength(1));
    expect(find.byType(TxnBubble), findsOneWidget);
  });

  testWidgets('transfer through the full form moves money between accounts', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _twoAccounts());
    await tester.tap(find.byTooltip('New transaction'));
    await tester.pumpAndSettle();

    await tester.tap(_inForm(find.text('Transfer')));
    await tester.pumpAndSettle();
    await tester.enterText(_inForm(find.widgetWithText(TextFormField, 'Amount')), '2000');
    // From: first account (Cash) is preselected; To: pick SBI Savings.
    await tester.tap(_inForm(find.text('Choose an account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SBI Savings').last);
    await tester.pumpAndSettle();
    await _tapInForm(tester, 'Save');

    expect(app.accounts.byId('cash').balance, 30000);
    expect(app.accounts.byId('bank').balance, 4200000);
    expect(app.txns.txns.single.type, TxnType.transfer);
  });

  testWidgets('edit a bubble, then delete it and undo', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _twoAccounts());
    await _openCashThread(tester);
    await _type(tester, '100 petrol');
    await _send(tester);

    await tester.tap(_inThread(find.text('−₹100')));
    await tester.pumpAndSettle();
    expect(find.text('Edit transaction'), findsOneWidget);
    await tester.enterText(_inForm(find.widgetWithText(TextFormField, 'Amount')), '150');
    await _tapInForm(tester, 'Save changes');

    expect(app.txns.txns.single.amount, 15000);
    expect(app.accounts.byId('cash').balance, 215000);

    await tester.tap(_inThread(find.text('−₹150')));
    await tester.pumpAndSettle();
    await _tapInForm(tester, 'Delete transaction');
    expect(app.txns.txns, isEmpty);
    expect(app.accounts.byId('cash').balance, 230000);
    expect(find.text('Undo'), findsOneWidget);
    // The toast sits above the composer, never on top of it.
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getBottomLeft(find.text('Undo')).dy, lessThan(tester.getTopLeft(find.byType(QuickComposer)).dy));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(app.txns.txns, hasLength(1));
    expect(app.accounts.byId('cash').balance, 215000);
  });

  testWidgets('long-press selects bubbles; delete removes them all', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _twoAccounts());
    await _openCashThread(tester);
    await _type(tester, '100 petrol');
    await _send(tester);
    await _type(tester, '50 chai');
    await _send(tester);
    expect(find.byType(TxnBubble), findsNWidgets(2));

    await tester.longPress(_inThread(find.text('−₹100')));
    await tester.pumpAndSettle();
    await tester.tap(_inThread(find.text('−₹50')));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(app.txns.txns, isEmpty);
    expect(find.text('Deleted 2 transactions'), findsOneWidget);
  });

  testWidgets('reconcile records the difference as an adjustment', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _twoAccounts());
    await _openCashThread(tester);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reconcile balance'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Actual balance'), '2000');
    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();

    expect(app.accounts.byId('cash').balance, 200000);
    expect(find.text('Cash adjusted by −₹300'), findsOneWidget);
    expect(_inThread(find.text('Balance adjusted')), findsOneWidget); // label, note not repeated
  });

  testWidgets('Transactions tab lists by day with totals and searches notes', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _twoAccounts());
    await _openCashThread(tester);
    await _type(tester, '540 groceries Big Bazaar');
    await _send(tester);
    await _type(tester, '120 petrol');
    await _send(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Transactions')));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionTile), findsNWidgets(2));
    expect(find.textContaining('TODAY · −₹660'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Search notes and categories'), 'bazaar');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionTile), findsOneWidget);
    expect(app.txns.txns, hasLength(2));
  });

  testWidgets('Settings → Categories adds a category', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _twoAccounts());
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Pets'), 'Pets');
    final add = find.text('Add category');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(find.text('Pets'), findsOneWidget);
    expect(app.categories.categories.last.name, 'Pets');
  });
}
