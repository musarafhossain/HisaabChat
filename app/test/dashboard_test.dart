import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_info.dart';
import 'package:hisaabchat/features/home/home_screen.dart';
import 'package:hisaabchat/features/reports/presentation/category_transactions.dart';
import 'package:hisaabchat/features/transactions/transactions_controller.dart';

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

Future<void> _add(TestApp app, String type, int paise, String category) => app.txns.create({
  'type': type,
  'amount': paise,
  'accountId': 'cash',
  'categoryId': app.categories.byName(category).id,
  'date': DateTime.now().toUtc().toIso8601String(),
});

/// Salary ₹30,000 in; ₹300 petrol + ₹1,200 groceries out; a ₹1,000 bike budget.
Future<void> _month(TestApp app) async {
  await _add(app, 'INCOME', 3000000, 'Salary');
  await _add(app, 'EXPENSE', 30000, 'Petrol');
  await _add(app, 'EXPENSE', 120000, 'Food & Groceries');
  await app.budgets.create({
    'name': 'Bike',
    'amount': 100000,
    'kind': 'VARIABLE',
    'categoryIds': [app.categories.byName('Petrol').id],
  });
}

void main() {
  testWidgets('Home shows money in/out, budget rings and recent transactions', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: _month);

    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('Money in'), findsOneWidget);
    expect(find.text('₹30,000'), findsOneWidget);
    expect(find.text('₹1,500'), findsOneWidget);

    expect(find.text('Budgets this month'), findsOneWidget);
    expect(find.text('Bike'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);

    expect(find.text('Recent'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Salary'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Food & Groceries'), findsOneWidget);

    // A budget ring opens that budget.
    await tester.scrollUntilVisible(find.text('Bike'), -200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Bike'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetInfoScreen), findsOneWidget);
  });

  testWidgets('Home invites a first budget when there are none', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash());

    expect(find.text('Set up a budget'), findsOneWidget);
    expect(find.text('No transactions yet'), findsOneWidget);
  });

  testWidgets('Home shows an offline banner and retries', (tester) async {
    final accounts = _cash();
    late TestApp app;
    await pumpApp(
      tester,
      savedToken: 'oat',
      accounts: accounts,
      seed: (a) async {
        app = a;
        a.reports.error = const ApiException(message: 'Waiting for network…', isNetworkError: true);
      },
    );

    expect(find.text('You’re offline. Can’t reach the server.'), findsOneWidget);
    // Accounts still load, so the balance stays visible.
    expect(find.text('Total balance'), findsOneWidget);

    app.reports.error = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('You’re offline. Can’t reach the server.'), findsNothing);
    expect(find.text('Set up a budget'), findsOneWidget);
  });

  testWidgets('Home refreshes after a transaction is saved', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    expect(find.text('No transactions yet'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    await container.read(txnMutationsProvider).create({
      'type': 'EXPENSE',
      'amount': 25000,
      'accountId': 'cash',
      'categoryId': app.categories.byName('Petrol').id,
      'date': DateTime.now().toUtc().toIso8601String(),
    });
    await tester.pumpAndSettle();

    expect(find.text('No transactions yet'), findsNothing);
    expect(find.text('₹250'), findsWidgets);
  });

  testWidgets('Reports rank categories and open their transactions', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), size: const Size(1280, 800), seed: _month);

    await tester.tap(find.byTooltip('Reports'));
    await tester.pumpAndSettle();

    expect(find.text('Spent'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget); // groceries: 1,200 of 1,500
    expect(find.text('20%'), findsOneWidget); // petrol
    expect(find.text('Money in vs out · last 6 months'), findsOneWidget);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.text('Spending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petrol'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryTransactionsScreen), findsOneWidget);
    expect(find.text('1 transaction · ₹300'), findsOneWidget);
  });

  testWidgets('Reports show an empty state for a quiet month', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), size: const Size(1280, 800));

    await tester.tap(find.byTooltip('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('No spending this month'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('Back to this month'), findsOneWidget);
  });
}
