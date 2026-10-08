import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';

import 'helpers.dart';

Future<void> _tap(WidgetTester tester, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('setup: month start, starter accounts and a budget, then Home', (tester) async {
    final repo = FakeAuthRepository(onboarded: false);
    final app = await pumpApp(tester, savedToken: 'oat', repo: repo);

    // Step 1: month start.
    expect(find.text('Your month'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    await tester.tap(find.text('1st (calendar month)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5th'));
    await tester.pumpAndSettle();
    await _tap(tester, 'Next');
    expect(repo.lastProfileUpdate, {'monthStartDay': 5});

    // Step 2: Cash is ticked by default; add UPI too.
    expect(find.text('Your money'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Cash in hand'), '5000');
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'UPI / wallet balance'), '1200');
    await _tap(tester, 'Next');

    final accounts = app.accounts.accounts;
    expect(accounts.map((a) => a.name), ['Cash', 'UPI']);
    expect(accounts.first.balance, 500000);
    expect(accounts.last.type, AccountType.wallet);

    // Step 3: a ticked budget needs an amount.
    expect(find.text('Your budgets'), findsOneWidget);
    await tester.tap(find.text('Bike EMI + Petrol'));
    await tester.pumpAndSettle();
    await _tap(tester, 'Finish');
    expect(find.text('Enter a monthly amount'), findsOneWidget);
    expect(repo.onboardingCompletions, 0);

    await tester.enterText(find.widgetWithText(TextFormField, 'Monthly amount'), '4000');
    await _tap(tester, 'Finish');

    expect(app.budgets.budgets.single.name, 'Bike EMI + Petrol');
    expect(app.budgets.budgets.single.amount, 400000);
    expect(repo.onboardingCompletions, 1);
    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('Bike EMI + Petrol'), findsOneWidget);
  });

  testWidgets('going back keeps answers and accounts are not created twice', (tester) async {
    final repo = FakeAuthRepository(onboarded: false);
    final app = await pumpApp(tester, savedToken: 'oat', repo: repo);

    await _tap(tester, 'Next');
    await _tap(tester, 'Next'); // creates Cash
    expect(app.accounts.accounts, hasLength(1));

    await _tap(tester, 'Back');
    expect(find.text('Your money'), findsOneWidget);
    // Now that an account exists, step 2 just lists it.
    expect(find.text('You already have these accounts. You can add more any time.'), findsOneWidget);
    await _tap(tester, 'Next');
    expect(app.accounts.accounts, hasLength(1));
  });

  testWidgets('setup can be skipped', (tester) async {
    final repo = FakeAuthRepository(onboarded: false);
    final app = await pumpApp(tester, savedToken: 'oat', repo: repo);

    await _tap(tester, 'Skip setup');
    expect(repo.onboardingCompletions, 1);
    expect(app.accounts.accounts, isEmpty);
    expect(find.text('Add your first account'), findsOneWidget);
  });
}
