import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/presentation/account_tile.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_info.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_widgets.dart';
import 'package:hisaabchat/features/people/presentation/people_widgets.dart';
import 'package:hisaabchat/features/reports/presentation/category_transactions.dart';
import 'package:hisaabchat/features/search/search_screen.dart';
import 'package:hisaabchat/features/transactions/presentation/account_thread.dart';
import 'package:hisaabchat/features/transactions/presentation/thread_widgets.dart';
import 'package:hisaabchat/features/transactions/presentation/transactions_section.dart';

import 'helpers.dart';

FakeAccountsRepository _cash() => FakeAccountsRepository([
  const Account(
    id: 'cash',
    name: 'Cash',
    type: AccountType.cash,
    openingBalance: 100000000,
    balance: 100000000,
    color: Color(0xFF16A34A),
    icon: 'payments',
    includeInTotal: true,
    archived: false,
  ),
]);

/// [count] expenses of ₹1 in [category], notes n001 (oldest) … nNNN (newest),
/// a minute apart, all this month.
Future<void> _expenses(TestApp app, int count, String category) async {
  final start = DateTime.now().toUtc().subtract(Duration(minutes: count + 1));
  for (var i = 1; i <= count; i++) {
    await app.txns.create({
      'type': 'EXPENSE',
      'amount': 100,
      'accountId': 'cash',
      'categoryId': app.categories.byName(category).id,
      'note': 'n${i.toString().padLeft(3, '0')}',
      'date': start.add(Duration(minutes: i)).toIso8601String(),
    });
  }
}

/// Drags [list] until [target] is built, or gives up.
Future<void> _scrollTo(WidgetTester tester, Finder target, Finder list, {bool up = false}) async {
  for (var i = 0; i < 80 && target.evaluate().isEmpty; i++) {
    await tester.drag(list, Offset(0, up ? 700 : -700));
    await tester.pumpAndSettle();
  }
  expect(target, findsWidgets);
}

void main() {
  testWidgets('Transactions tab: 90 entries load 40 at a time as you scroll', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: (a) => _expenses(a, 90, 'Petrol'));
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Transactions')));
    await tester.pumpAndSettle();
    final before = app.txns.listCalls;

    // Totals cover all 90 from the first page.
    expect(find.text('−₹90'), findsWidgets);
    expect(find.text('Cash · n001'), findsNothing);
    // The day header never shows the sum of just the first page (40 × ₹1).
    expect(find.textContaining('−₹40'), findsNothing);

    await _scrollTo(tester, find.text('Cash · n001'), find.byType(ListView).last);
    expect(find.textContaining('−₹40'), findsNothing);
    expect(app.txns.listCalls - before, greaterThanOrEqualTo(2)); // pages 2 and 3
    expect(find.byType(TransactionTile), findsWidgets);
  });

  testWidgets('account chat: scrolling up loads older entries', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: (a) => _expenses(a, 70, 'Petrol'));
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Accounts')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AccountTile, 'Cash').first);
    await tester.pumpAndSettle();

    expect(find.text('n070'), findsOneWidget); // newest at the bottom
    await _scrollTo(
      tester,
      find.text('n001'),
      find.descendant(of: find.byType(AccountThreadScreen), matching: find.byType(ListView)),
      up: true,
    );
    expect(find.text('Account opened with ₹10,00,000'), findsOneWidget);
  });

  testWidgets('person chat: more than 40 entries, scrolling up loads the rest', (tester) async {
    await pumpApp(
      tester,
      savedToken: 'oat',
      accounts: _cash(),
      seed: (a) async {
        final amit = a.people.add('Amit');
        final start = DateTime.now().toUtc().subtract(const Duration(hours: 2));
        for (var i = 1; i <= 55; i++) {
          await a.txns.create({
            'type': i.isEven ? 'COLLECT' : 'LEND',
            'amount': 100,
            'accountId': 'cash',
            'personId': amit,
            'note': 'p${i.toString().padLeft(3, '0')}',
            'date': start.add(Duration(minutes: i)).toIso8601String(),
          });
        }
      },
    );
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('People').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PersonTile, 'Amit'));
    await tester.pumpAndSettle();

    expect(find.text('p055'), findsOneWidget);
    expect(find.text('p001'), findsNothing); // beyond the first 40
    await _scrollTo(tester, find.text('p001'), find.byType(ListView).last, up: true);
    expect(find.byType(TxnBubble), findsWidgets);
  });

  testWidgets('Reports → category: the count and total cover all 120, and every one loads', (tester) async {
    await pumpApp(
      tester,
      savedToken: 'oat',
      accounts: _cash(),
      size: const Size(1280, 800),
      seed: (a) => _expenses(a, 120, 'Petrol'),
    );
    await tester.tap(find.byTooltip('Reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petrol').first);
    await tester.pumpAndSettle();

    expect(find.byType(CategoryTransactionsScreen), findsOneWidget);
    expect(find.text('120 transactions · ₹120'), findsOneWidget);
    await _scrollTo(tester, find.text('Cash · n001'), find.byType(ListView).last);
  });

  testWidgets('budget page: expenses are counted on the server and page in', (tester) async {
    await pumpApp(
      tester,
      savedToken: 'oat',
      accounts: _cash(),
      seed: (a) async {
        await _expenses(a, 60, 'Petrol');
        await _expenses(a, 5, 'Room Rent'); // not in the budget
        await a.budgets.create({
          'name': 'Bike',
          'amount': 500000,
          'kind': 'VARIABLE',
          'categoryIds': [a.categories.byName('Petrol').id],
        });
      },
    );
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Budgets')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BudgetTile, 'Bike'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetInfoScreen), findsOneWidget);

    final list = find.descendant(of: find.byType(BudgetInfoScreen), matching: find.byType(ListView));
    await _scrollTo(tester, find.text('Expenses this period (60)'), list);
    await _scrollTo(tester, find.text('Cash · n001'), list);
  });

  testWidgets('search: all matches page in, with the full count', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: (a) => _expenses(a, 50, 'Petrol'));
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(SearchScreen), matching: find.byType(TextField)), 'petrol');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Transactions · 50'), findsOneWidget);
    await _scrollTo(tester, find.text('Cash · n001'), find.byType(ListView).last);
  });
}
