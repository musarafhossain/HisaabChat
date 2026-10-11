import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_info.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_summary.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_widgets.dart';
import 'package:intl/intl.dart';

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

/// Food ₹2,500 (₹200 carried in, ₹2,000 spent) and Room Rent ₹3,200 (paid).
Future<void> _seed(TestApp app, {bool carry = true}) async {
  Future<void> budget(String name, int amount, String category) => app.budgets.create({
    'name': name,
    'amount': amount,
    'kind': 'VARIABLE',
    'categoryIds': [app.categories.byName(category).id],
  });
  await budget('Food & Groceries', 250000, 'Food & Groceries');
  await budget('Room Rent', 320000, 'Room Rent');
  if (carry) app.budgets.budgets.first.carried = 20000;
  for (final (amount, category) in [(200000, 'Food & Groceries'), (320000, 'Room Rent')]) {
    await app.txns.create({
      'type': 'EXPENSE',
      'amount': amount,
      'accountId': 'cash',
      'categoryId': app.categories.byName(category).id,
      'date': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

Future<void> _openBudgets(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Budgets')));
  await tester.pumpAndSettle();
}

Finder _inSummary(Finder finder) => find.descendant(of: find.byType(BudgetSummaryView), matching: finder);

void main() {
  final thisMonth = DateFormat('MMMM').format(DateTime.now());

  testWidgets('the Budgets tab shows only this month, with a line that opens the summary', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: _seed);
    await _openBudgets(tester);

    // No month arrows on the tab any more.
    expect(find.byTooltip('Previous month'), findsNothing);
    expect(find.textContaining('$thisMonth · '), findsOneWidget);
    // ₹2,500 + ₹200 carried + ₹3,200 = ₹5,900; ₹5,200 spent → ₹700 left.
    expect(find.text(' left of ₹5,900'), findsOneWidget);
    expect(find.text('Includes ₹200 carried over'), findsOneWidget);
    expect(find.byType(BudgetTile), findsNWidgets(2));

    await tester.tap(find.text(' left of ₹5,900'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetSummaryScreen), findsOneWidget);
  });

  testWidgets('the summary explains where the money comes from', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: _seed);
    await _openBudgets(tester);
    await tester.tap(find.text(' left of ₹5,900'));
    await tester.pumpAndSettle();

    expect(_inSummary(find.text('Monthly amounts')), findsOneWidget);
    expect(_inSummary(find.text('₹5,700')), findsOneWidget); // 2,500 + 3,200
    expect(_inSummary(find.text('Carried from earlier months')), findsOneWidget);
    expect(_inSummary(find.text('+₹200')), findsOneWidget);
    expect(_inSummary(find.text('Total this month')), findsOneWidget);
    expect(_inSummary(find.text('₹5,900')), findsWidgets); // also in the month-by-month table
    expect(_inSummary(find.text('₹700')), findsWidgets); // left (also in the table)

    // Each budget's own maths.
    expect(_inSummary(find.text('₹2,500 + ₹200 carried = ₹2,700')), findsOneWidget);
    expect(_inSummary(find.text('₹700 left')), findsOneWidget);
    expect(_inSummary(find.text('₹3,200')), findsWidgets);

    // Month by month: this month's row plus earlier ones before the budgets existed.
    await tester.scrollUntilVisible(
      find.textContaining('Carry over is on for 1 budget'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(_inSummary(find.text(DateFormat('MMM y').format(DateTime.now()))), findsOneWidget);
    expect(_inSummary(find.text('—')), findsNWidgets(15)); // five earlier months × 3 columns

    // A budget row opens that budget.
    await tester.scrollUntilVisible(find.text('Room Rent'), -300, scrollable: find.byType(Scrollable).last);
    await tester.tap(_inSummary(find.text('Room Rent')));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetInfoScreen), findsOneWidget);
  });

  testWidgets('earlier months are browsed in the summary, not on the tab', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: (a) => _seed(a, carry: false));
    await _openBudgets(tester);
    await tester.tap(find.text(' left of ₹5,700'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Carry over is off'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.scrollUntilVisible(find.byTooltip('Previous month'), -300, scrollable: find.byType(Scrollable).last);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    final last = DateTime(DateTime.now().year, DateTime.now().month - 1);
    expect(find.text(DateFormat('MMMM y').format(last)), findsOneWidget);
    expect(find.text('Back to this month'), findsOneWidget);

    await tester.tap(find.text('Back to this month'));
    await tester.pumpAndSettle();
    expect(find.text('Back to this month'), findsNothing);

    // The tab still shows this month after browsing.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(' left of ₹5,700'), findsOneWidget);
  });

  testWidgets('desktop: the summary opens beside the list', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: _seed, size: const Size(1280, 800));
    await tester.tap(find.byTooltip('Budgets'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(' left of ₹5,900'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetSummaryView), findsOneWidget);
    expect(find.byType(BudgetSummaryScreen), findsNothing); // in the pane, not a new page

    await tester.tap(find.widgetWithText(BudgetTile, 'Room Rent'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetSummaryView), findsNothing);
    expect(find.byType(BudgetInfoView), findsOneWidget);
  });
}
