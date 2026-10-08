import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/recurring/data/recurring.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';

import 'helpers.dart';

FakeAccountsRepository _cash() => FakeAccountsRepository([
  const Account(
    id: 'cash',
    name: 'Cash',
    type: AccountType.cash,
    openingBalance: 10000000,
    balance: 10000000,
    color: Color(0xFF16A34A),
    icon: 'payments',
    includeInTotal: true,
    archived: false,
  ),
]);

const _cashRef = AccountRef(id: 'cash', name: 'Cash', icon: 'payments', color: Color(0xFF16A34A));

RecurringRule _rule(TestApp app, String id, String category, int amount, {bool autoCreate = false}) {
  final c = app.categories.byName(category);
  return RecurringRule(
    id: id,
    type: TxnType.expense,
    amount: amount,
    account: _cashRef,
    category: CategoryRef(id: c.id, name: c.name, icon: c.icon, color: c.color),
    frequency: Frequency.monthly,
    interval: 1,
    dayOfMonth: 5,
    startDate: DateTime(2026, 1, 5),
    autoCreate: autoCreate,
    isActive: true,
    nextDate: DateTime.now().add(const Duration(days: 3)),
  );
}

Finder _inForm(Finder finder) => find.descendant(of: find.byType(TxnForm), matching: finder);

void main() {
  testWidgets('"Repeat" in the form makes the new transaction recurring', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    await tester.tap(find.byTooltip('New transaction'));
    await tester.pumpAndSettle();

    await tester.enterText(_inForm(find.widgetWithText(TextFormField, 'Amount')), '3200');
    await tester.tap(_inForm(find.text('Bike EMI')));
    await tester.pumpAndSettle();

    final repeat = _inForm(find.text('Doesn’t repeat'));
    await tester.ensureVisible(repeat);
    await tester.pumpAndSettle();
    await tester.tap(repeat);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Monthly on the').last);
    await tester.pumpAndSettle();
    expect(_inForm(find.text('Add automatically')), findsOneWidget);

    final save = _inForm(find.text('Save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final txn = app.txns.txns.single;
    final body = app.recurring.created.single;
    expect(body['frequency'], 'MONTHLY');
    expect(body['dayOfMonth'], DateTime.now().day);
    expect(body['autoCreate'], isTrue);
    expect(body['linkTransactionId'], txn.id);
    expect(app.txns.txns.single.isRecurring, isTrue);
  });

  testWidgets('Home "Due soon": confirm a reminder with a new amount, skip another', (tester) async {
    final app = await pumpApp(
      tester,
      savedToken: 'oat',
      accounts: _cash(),
      seed: (a) async {
        final today = DateTime.now();
        a.recurring.upcomingValue = Upcoming(
          today: DateTime(today.year, today.month, today.day),
          pending: [
            PendingOccurrence(
              id: 'occ-rent',
              dueDate: DateTime(today.year, today.month, today.day),
              rule: _rule(a, 'rule-rent', 'Room Rent', 900000),
            ),
            PendingOccurrence(
              id: 'occ-fees',
              dueDate: DateTime(today.year, today.month, today.day),
              rule: _rule(a, 'rule-fees', 'Education', 250000),
            ),
          ],
          upcoming: [
            (
              date: DateTime(today.year, today.month, today.day).add(const Duration(days: 3)),
              rule: _rule(a, 'rule-emi', 'Bike EMI', 320000, autoCreate: true),
            ),
          ],
          dues: const [],
        );
      },
    );

    expect(find.text('Due soon'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // count badge
    expect(find.text('Bike EMI'), findsOneWidget);
    expect(find.text('In 3 days · Adds itself'), findsOneWidget);

    await tester.tap(find.text('Confirm').first);
    await tester.pumpAndSettle();
    expect(find.text('Confirm Room Rent'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '9500');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final rent = app.txns.txns.single;
    expect(rent.amount, 950000);
    expect(rent.category?.name, 'Room Rent');
    expect(app.accounts.byId('cash').balance, 10000000 - 950000);
    expect(find.text('Room Rent added'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(app.recurring.skipped, ['occ-fees']);
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets('Settings → Recurring lists rules with their schedule', (tester) async {
    await pumpApp(
      tester,
      savedToken: 'oat',
      accounts: _cash(),
      seed: (a) async => a.recurring.rules.add(_rule(a, 'rule-emi', 'Bike EMI', 320000, autoCreate: true)),
    );
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recurring'));
    await tester.pumpAndSettle();

    expect(find.text('Bike EMI'), findsOneWidget);
    expect(find.text('Monthly on the 5th · Auto-add · Cash'), findsOneWidget);
    expect(find.text('−₹3,200'), findsOneWidget);
  });
}
