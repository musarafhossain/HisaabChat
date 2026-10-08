import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/presentation/account_tile.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_form.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_widgets.dart';
import 'package:hisaabchat/features/transactions/presentation/quick_composer.dart';

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

Finder _inForm(Finder finder) => find.descendant(of: find.byType(BudgetForm), matching: finder);

Future<void> _openBudgets(WidgetTester tester, {bool desktop = false}) async {
  await tester.tap(
    desktop
        ? find.byTooltip('Budgets')
        : find.descendant(of: find.byType(NavigationBar), matching: find.text('Budgets')),
  );
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, String label) async {
  final button = _inForm(find.text(label));
  // Let the text field's own scroll-to-caret finish first.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _spend(TestApp app, int paise, String category) => app.txns.create({
  'type': 'EXPENSE',
  'amount': paise,
  'accountId': 'cash',
  'categoryId': app.categories.byName(category).id,
  'date': DateTime.now().toUtc().toIso8601String(),
});

Future<void> _budget(TestApp app, String name, int paise, List<String> categories, {String kind = 'VARIABLE'}) =>
    app.budgets.create({
      'name': name,
      'amount': paise,
      'kind': kind,
      'categoryIds': [for (final c in categories) app.categories.byName(c).id],
    });

void main() {
  testWidgets('create "Bike EMI + Petrol" from a suggestion', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    await _openBudgets(tester);

    expect(find.text('Set your first budget'), findsOneWidget);
    await tester.tap(find.text('Bike EMI + Petrol'));
    await tester.pumpAndSettle();

    // Name and categories come from the template.
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: _inForm(find.byType(TextFormField).first), matching: find.byType(EditableText)),
          )
          .controller
          .text,
      'Bike EMI + Petrol',
    );
    expect(tester.widget<FilterChip>(_inForm(find.widgetWithText(FilterChip, 'Bike EMI'))).selected, isTrue);
    expect(tester.widget<FilterChip>(_inForm(find.widgetWithText(FilterChip, 'Petrol'))).selected, isTrue);

    await tester.enterText(_inForm(find.widgetWithText(TextFormField, 'e.g. 4000')), '5000');
    await _submit(tester, 'Create budget');

    expect(find.widgetWithText(BudgetTile, 'Bike EMI + Petrol'), findsOneWidget);
    expect(app.budgets.budgets.single.amount, 500000);
    expect(app.categories.byName('Petrol').budgetId, app.budgets.budgets.single.id);
  });

  testWidgets('spending shows on the ring, percent pill and summary', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    await _budget(app, 'Bike EMI + Petrol', 500000, ['Bike EMI', 'Petrol']);
    await _spend(app, 320000, 'Bike EMI');
    await _spend(app, 20000, 'Petrol');
    await _spend(app, 54000, 'Food & Groceries');
    await _openBudgets(tester);

    expect(find.text('68%'), findsWidgets);
    expect(find.textContaining('₹3,400 of ₹5,000'), findsOneWidget);
    expect(find.text('Not in any budget'), findsOneWidget);
    expect(find.text('₹540'), findsOneWidget);
  });

  testWidgets('categories already in a budget are disabled in the form', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    await _budget(app, 'Bike', 500000, ['Petrol']);
    await _openBudgets(tester);

    await tester.tap(find.byTooltip('New budget'));
    await tester.pumpAndSettle();
    final petrol = tester.widget<FilterChip>(_inForm(find.widgetWithText(FilterChip, 'Petrol · in Bike')));
    expect(petrol.onSelected, isNull);
  });

  testWidgets('an expense that crosses the alert level shows a warning toast', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    await _budget(app, 'Food', 100000, ['Food & Groceries']);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Accounts')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AccountTile, 'Cash').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(QuickComposer), matching: find.byType(TextField)),
      '850 groceries',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Food · 85% used'), findsOneWidget);
  });

  testWidgets('change the amount for this month only', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    await _budget(app, 'Education', 200000, ['Education'], kind: 'FIXED');
    await _openBudgets(tester);

    await tester.tap(find.widgetWithText(BudgetTile, 'Education'));
    await tester.pumpAndSettle();
    final change = find.text('Change amount for this month only');
    await tester.scrollUntilVisible(change, 300, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(change);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '15000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(app.budgets.budgets.single.overrides.values.single, 1500000);
    expect(find.text('This month only · usually ₹2,000'), findsOneWidget);
  });

  testWidgets('desktop: open a budget in the detail pane and archive it', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat', accounts: _cash(), size: const Size(1400, 900));
    await _budget(app, 'Food', 400000, ['Food & Groceries', 'Eating Out']);
    await _openBudgets(tester, desktop: true);

    await tester.tap(find.widgetWithText(BudgetTile, 'Food'));
    await tester.pumpAndSettle();
    expect(find.text('Last 6 months'), findsOneWidget);
    expect(find.text('Eating Out'), findsWidgets);

    final archive = find.text('Archive budget');
    await tester.scrollUntilVisible(archive, 300, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(archive);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(app.budgets.budgets, isEmpty);
    expect(app.categories.byName('Eating Out').budgetId, isNull);
    expect(find.text('Set your first budget'), findsOneWidget);
    expect(find.text('Select a budget to see how it’s going'), findsOneWidget);
  });
}
