import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/core/network/api_exception.dart';

import 'helpers.dart';

void main() {
  testWidgets('signed-out users land on Welcome and can log in', (tester) async {
    final app = await pumpApp(tester);

    expect(find.text('Welcome to HisaabChat'), findsOneWidget);

    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'asha@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Asha'), findsWidgets);
    expect(find.text('Add your first account'), findsOneWidget);
    expect(app.tokens.token, 'oat_test');
  });

  testWidgets('a wrong password shows an error and stays on Login', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'asha@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'nope-nope');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password'), findsOneWidget);
    expect(find.text('Add your first account'), findsNothing);
  });

  testWidgets('client-side validation runs before calling the API', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('register creates an account and opens setup, then Home', (tester) async {
    final app = await pumpApp(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Neha Sen');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'neha@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password (at least 8 characters)'), 'long-password');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'long-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Your month'), findsOneWidget);
    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Neha'), findsWidgets);
    expect(app.repo.onboardingCompletions, 1);
    expect(app.tokens.token, 'oat_new');
  });

  testWidgets('register shows a taken email next to the field', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Asha');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'asha@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password (at least 8 characters)'), 'long-password');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'other-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords don’t match'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'long-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('An account with this email already exists'), findsOneWidget);
  });

  testWidgets('a saved session skips Welcome', (tester) async {
    await pumpApp(tester, savedToken: 'oat_saved');

    expect(find.text('Welcome to HisaabChat'), findsNothing);
    expect(find.text('Add your first account'), findsOneWidget);
  });

  testWidgets('an expired token signs the user out', (tester) async {
    final repo = FakeAuthRepository(meError: const ApiException(message: 'Unauthorized', statusCode: 401));
    final app = await pumpApp(tester, savedToken: 'oat_expired', repo: repo);

    expect(find.text('Welcome to HisaabChat'), findsOneWidget);
    expect(app.tokens.token, isNull);
  });

  testWidgets('an unreachable API shows a retry on the splash screen', (tester) async {
    final repo = FakeAuthRepository(meError: const ApiException(message: 'Waiting for network…', isNetworkError: true));
    await pumpApp(tester, savedToken: 'oat_saved', repo: repo);

    expect(find.text('Waiting for network…'), findsOneWidget);

    repo.meError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Add your first account'), findsOneWidget);
  });

  testWidgets('logout from Settings returns to Welcome', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat_saved');

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('asha@example.com'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to HisaabChat'), findsOneWidget);
    expect(app.repo.logoutCalls, 1);
    expect(app.tokens.token, isNull);
  });
}
