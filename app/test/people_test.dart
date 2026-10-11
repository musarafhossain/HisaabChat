import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/categories/data/category.dart';
import 'package:hisaabchat/features/people/presentation/people_widgets.dart';
import 'package:hisaabchat/features/people/presentation/person_form.dart';
import 'package:hisaabchat/features/people/presentation/person_thread.dart';
import 'package:hisaabchat/features/people/presentation/write_off_dialog.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';

import 'helpers.dart';

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

Future<void> _openPeople(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('People').last);
  await tester.pumpAndSettle();
}

Finder _composerField() => find.descendant(of: find.byType(PersonComposer), matching: find.byType(TextField));

void main() {
  testWidgets('add a person from the empty People list', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    await _openPeople(tester);

    expect(find.text('No one yet'), findsOneWidget);
    await tester.tap(find.text('Add person'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Amit');
    await tester.tap(find.descendant(of: find.byType(PersonForm), matching: find.text('Add person')));
    await tester.pumpAndSettle();

    expect(app.people.rows.single.name, 'Amit');
    expect(find.widgetWithText(PersonTile, 'Amit'), findsOneWidget);
    expect(find.text('Settled up'), findsOneWidget);
  });

  testWidgets('phone: the + keeps adding people once the list isn’t empty', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: (a) async => a.people.add('Amit'));
    await _openPeople(tester);
    expect(find.text('No one yet'), findsNothing);

    await tester.tap(find.byTooltip('New person'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Riya');
    await tester.tap(find.descendant(of: find.byType(PersonForm), matching: find.text('Add person')));
    await tester.pumpAndSettle();

    expect(app.people.rows.map((r) => r.name), ['Amit', 'Riya']);
    expect(find.widgetWithText(PersonTile, 'Riya'), findsOneWidget);
  });

  testWidgets('lend in a person’s chat, see who owes what, then settle up', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: (a) async => a.people.add('Amit'));
    await _openPeople(tester);
    await tester.tap(find.widgetWithText(PersonTile, 'Amit'));
    await tester.pumpAndSettle();
    expect(find.byType(PersonThreadScreen), findsOneWidget);

    // "Lent" is preselected; money comes from Cash.
    await tester.enterText(_composerField(), '500 movie');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    final lent = app.txns.txns.single;
    expect(lent.type, TxnType.lend);
    expect(lent.amount, 50000);
    expect(lent.note, 'movie');
    expect(app.accounts.byId('cash').balance, 950000);
    expect(find.text('You lent · Cash'), findsOneWidget);
    expect(find.text('Amit owes you ₹500'), findsOneWidget);

    // Settle up: record ₹500 received into Cash.
    await tester.tap(find.text('Settle up').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record received'));
    await tester.pumpAndSettle();

    expect(app.txns.txns.last.type, TxnType.collect);
    expect(app.accounts.byId('cash').balance, 1000000);
    expect(find.text('Amit owes you ₹500'), findsNothing);
    expect(find.text('Settled up with Amit'), findsOneWidget);
  });

  testWidgets('borrowing shows on Home as "You owe"', (tester) async {
    await pumpApp(
      tester,
      savedToken: 'oat',
      accounts: _cash(),
      seed: (a) async {
        final riya = a.people.add('Riya');
        await a.txns.create({
          'type': 'BORROW',
          'amount': 30000,
          'accountId': 'cash',
          'personId': riya,
          'date': DateTime.now().toUtc().toIso8601String(),
        });
      },
    );

    expect(find.text('You’ll get'), findsOneWidget);
    expect(find.text('You owe'), findsOneWidget);
    expect(find.text('₹300'), findsWidgets);
  });

  testWidgets('desktop: People in the rail opens the chat beside the list', (tester) async {
    await pumpApp(
      tester,
      savedToken: 'oat',
      accounts: _cash(),
      size: const Size(1280, 800),
      seed: (a) async => a.people.add('Amit'),
    );
    await tester.tap(find.byTooltip('People'));
    await tester.pumpAndSettle();
    expect(find.text('Select someone to see what you lent and borrowed'), findsOneWidget);

    await tester.tap(find.widgetWithText(PersonTile, 'Amit'));
    await tester.pumpAndSettle();
    expect(find.byType(PersonThread), findsOneWidget);
    expect(find.text('Nothing with Amit yet. Pick Lent or Borrowed below and type an amount.'), findsOneWidget);
  });

  group('write off', () {
    TxnCategory cat(String name, CategoryType type, {String? parentId, bool archived = false}) => TxnCategory(
      id: name,
      name: name,
      type: type,
      color: const Color(0xFF10B981),
      icon: 'redeem',
      sortOrder: 0,
      isDefault: true,
      archived: archived,
      parentId: parentId,
    );

    test('starts on Gifts / Other / Other Income, else the first of that type', () {
      final all = [
        cat('Room Rent', CategoryType.expense),
        cat('Gifts', CategoryType.expense, archived: true),
        cat('Other', CategoryType.expense),
        cat('Salary', CategoryType.income),
        cat('Other Income', CategoryType.income),
      ];
      expect(defaultWriteOffCategory(all, CategoryType.expense)?.name, 'Other'); // Gifts is archived
      expect(defaultWriteOffCategory(all, CategoryType.income)?.name, 'Other Income');
      expect(
        defaultWriteOffCategory([cat('Room Rent', CategoryType.expense)], CategoryType.expense)?.name,
        'Room Rent',
      );
      expect(defaultWriteOffCategory([], CategoryType.income), isNull);
    });

    testWidgets('part of what Amit owes becomes spending; Cash doesn’t change', (tester) async {
      final app = await pumpApp(
        tester,
        savedToken: 'oat',
        accounts: _cash(),
        seed: (a) async {
          final amit = a.people.add('Amit');
          await a.txns.create({
            'type': 'LEND',
            'amount': 50000,
            'accountId': 'cash',
            'personId': amit,
            'date': DateTime.now().toUtc().toIso8601String(),
          });
        },
      );
      await _openPeople(tester);
      await tester.tap(find.widgetWithText(PersonTile, 'Amit'));
      await tester.pumpAndSettle();
      final cashBefore = app.accounts.byId('cash').balance;

      await tester.tap(find.byTooltip('More options').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Write off'));
      await tester.pumpAndSettle();
      expect(find.text('Write off with Amit?'), findsOneWidget);
      expect(find.textContaining('Amit owes you ₹500. Writing it off'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '200');
      await tester.tap(find.byKey(const ValueKey('write-off-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eating Out').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Write off'));
      await tester.pumpAndSettle();

      expect(app.people.writeOffCalls, 1);
      final [settlement, expense] = app.txns.txns.sublist(app.txns.txns.length - 2);
      expect(settlement.type, TxnType.collect);
      expect(expense.type, TxnType.expense);
      expect(expense.amount, 20000);
      expect(expense.category?.name, 'Eating Out');
      expect(app.accounts.byId('cash').balance, cashBefore);
      expect(app.people.balanceOf(app.people.rows.single.id), 30000);
      expect(find.text('Wrote off ₹200 with Amit'), findsOneWidget);
      expect(find.text('Amit owes you ₹300'), findsOneWidget);
    });

    testWidgets('what you owe Riya becomes income, and more than that is refused', (tester) async {
      final app = await pumpApp(
        tester,
        savedToken: 'oat',
        accounts: _cash(),
        seed: (a) async {
          final riya = a.people.add('Riya');
          await a.txns.create({
            'type': 'BORROW',
            'amount': 30000,
            'accountId': 'cash',
            'personId': riya,
            'date': DateTime.now().toUtc().toIso8601String(),
          });
        },
      );
      await _openPeople(tester);
      await tester.tap(find.widgetWithText(PersonTile, 'Riya'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More options').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Write off'));
      await tester.pumpAndSettle();
      expect(find.textContaining('counted as income'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget); // first income category in the test data

      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '301');
      await tester.tap(find.widgetWithText(FilledButton, 'Write off'));
      await tester.pumpAndSettle();
      expect(find.text('That’s more than ₹300'), findsOneWidget);
      expect(app.people.writeOffCalls, 0);

      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '300');
      await tester.tap(find.widgetWithText(FilledButton, 'Write off'));
      await tester.pumpAndSettle();
      expect(app.txns.txns.last.type, TxnType.income);
      expect(app.people.balanceOf(app.people.rows.single.id), 0);
      expect(app.accounts.byId('cash').balance, 1030000);
    });
  });
}
