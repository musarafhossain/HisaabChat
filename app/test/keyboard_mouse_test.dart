import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/presentation/account_tile.dart';
import 'package:hisaabchat/features/people/presentation/people_widgets.dart';
import 'package:hisaabchat/features/transactions/presentation/thread_widgets.dart';
import 'package:hisaabchat/features/transactions/presentation/transactions_section.dart';
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';

import 'helpers.dart';

const _desktop = Size(1280, 800);

FakeAccountsRepository _cash() => FakeAccountsRepository([
  const Account(
    id: 'cash',
    name: 'Cash',
    type: AccountType.cash,
    openingBalance: 1000000,
    balance: 1000000,
    color: Color(0xFF16A34A),
    icon: 'payments',
    includeInTotal: true,
    archived: false,
  ),
]);

/// Two expenses on Cash (₹120 Snacks, ₹80 Tea) and a person, Amit.
Future<void> _seed(TestApp app) async {
  for (final (amount, note) in [(12000, 'Snacks'), (8000, 'Tea')]) {
    await app.txns.create({
      'type': 'EXPENSE',
      'amount': amount,
      'accountId': 'cash',
      'categoryId': app.categories.byName('Food & Groceries').id,
      'note': note,
      'date': DateTime.now().toUtc().toIso8601String(),
    });
  }
  app.people.add('Amit');
}

Future<void> _rightClick(WidgetTester tester, Finder finder) async {
  await tester.tap(finder, buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

Future<void> _openTransactions(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Transactions'));
  await tester.pumpAndSettle();
}

Finder _tile(String note) => find.ancestor(of: find.textContaining(note), matching: find.byType(TransactionTile)).first;

void main() {
  testWidgets('Ctrl+N opens a new transaction from anywhere', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), size: _desktop);
    await tester.tap(find.byTooltip('Accounts'));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byType(TxnForm), findsOneWidget);
    expect(find.text('New transaction'), findsWidgets);
  });

  testWidgets('right-click a transaction: Duplicate, then Delete with Undo', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: _seed, size: _desktop);
    await _openTransactions(tester);

    await _rightClick(tester, _tile('Snacks'));
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    expect(app.txns.txns.where((t) => t.note == 'Snacks'), hasLength(2));
    expect(find.text('Duplicated'), findsOneWidget);

    await _rightClick(tester, _tile('Tea'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(app.txns.txns.where((t) => t.note == 'Tea'), isEmpty);
    expect(app.accounts.byId('cash').balance, 1000000 - 12000 * 2);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(app.txns.txns.where((t) => t.note == 'Tea'), hasLength(1));
  });

  testWidgets('right-click → Edit opens the form', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: _seed, size: _desktop);
    await _openTransactions(tester);
    await _rightClick(tester, _tile('Tea'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit transaction'), findsWidgets);
  });

  testWidgets('desktop: Del deletes the open transaction, but not while typing', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: _seed, size: _desktop);
    await _openTransactions(tester);
    await tester.tap(_tile('Tea'));
    await tester.pumpAndSettle();
    expect(find.text('Edit transaction'), findsOneWidget);

    // Typing in the note: Delete edits the text.
    await tester.tap(find.widgetWithText(TextFormField, 'Tea'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(app.txns.txns.where((t) => t.note == 'Tea'), hasLength(1));

    // Back on the list: Delete removes it.
    await tester.tap(_tile('Tea'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(app.txns.txns.where((t) => t.note == 'Tea'), isEmpty);
    expect(find.textContaining('Deleted ₹80'), findsOneWidget);
    expect(find.text('Edit transaction'), findsNothing);
  });

  testWidgets('account chat: right-click → Select, then Del deletes the selection', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: _seed, size: _desktop);
    await tester.tap(find.byTooltip('Accounts'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AccountTile, 'Cash').first);
    await tester.pumpAndSettle();

    await _rightClick(tester, find.ancestor(of: find.textContaining('Snacks'), matching: find.byType(TxnBubble)).first);
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(app.txns.txns.where((t) => t.note == 'Snacks'), isEmpty);
    expect(find.text('1 selected'), findsNothing);
  });

  testWidgets('right-click an account or a person for their actions', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: _seed, size: _desktop);
    await tester.tap(find.byTooltip('Accounts'));
    await tester.pumpAndSettle();
    await _rightClick(tester, find.widgetWithText(AccountTile, 'Cash').first);
    for (final label in ['Open', 'Edit account', 'Reconcile balance', 'Export CSV', 'Archive']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('Edit account'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Cash'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // Amit owes nothing yet: no Settle up / Write off.
    await tester.tap(find.byTooltip('People'));
    await tester.pumpAndSettle();
    await _rightClick(tester, find.widgetWithText(PersonTile, 'Amit'));
    expect(find.text('Open chat'), findsOneWidget);
    expect(find.text('Settle up'), findsNothing);
    expect(find.text('Edit name'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
  });
}
