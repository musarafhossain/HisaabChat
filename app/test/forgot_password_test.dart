import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> _openForgotPassword(WidgetTester tester, {String email = ''}) async {
  await tester.tap(find.text('I already have an account'));
  await tester.pumpAndSettle();
  if (email.isNotEmpty) await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.tap(find.text('Forgot password?'));
  await tester.pumpAndSettle();
}

Finder _field(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText));

void main() {
  testWidgets('email → code → new password signs you in', (tester) async {
    final app = await pumpApp(tester);
    await _openForgotPassword(tester, email: 'asha@example.com');

    // The email typed on Login is carried over.
    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    await tester.pumpAndSettle();
    expect(app.repo.forgotPasswordEmails, ['asha@example.com']);
    expect(find.text('Check your email'), findsOneWidget);

    // A wrong code shows under the field.
    await tester.enterText(find.byKey(const ValueKey('reset-code')), '000000');
    await tester.enterText(_field('reset-password'), 'new-password-1');
    await tester.enterText(_field('reset-confirm'), 'new-password-1');
    await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
    await tester.pumpAndSettle();
    expect(find.text('That code is wrong or has expired'), findsOneWidget);
    expect(app.tokens.token, isNull);

    await tester.enterText(find.byKey(const ValueKey('reset-code')), FakeAuthRepository.resetCode);
    await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
    await tester.pumpAndSettle();

    expect(app.repo.password, 'new-password-1');
    expect(app.tokens.token, 'oat_test');
    expect(find.text('Add your first account'), findsOneWidget);
    expect(find.text('Password changed. You’re signed in.'), findsOneWidget);
  });

  testWidgets('checks the email, the code and the new password before calling the API', (tester) async {
    final app = await pumpApp(tester);
    await _openForgotPassword(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(app.repo.forgotPasswordEmails, isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'asha@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    await tester.pumpAndSettle();

    // Only digits, at most 6.
    await tester.enterText(find.byKey(const ValueKey('reset-code')), '12ab34567');
    expect(find.text('123456'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('reset-code')), '123');
    await tester.enterText(_field('reset-password'), 'short');
    await tester.enterText(_field('reset-confirm'), 'different');
    await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the 6 digits from the email'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(find.text('Passwords don’t match'), findsOneWidget);

    // Send again, or go back to change the email.
    await tester.tap(find.text('Send a new code'));
    await tester.pumpAndSettle();
    expect(app.repo.forgotPasswordEmails, hasLength(2));
    expect(find.text('Sent a new code to asha@example.com'), findsOneWidget);
    await tester.tap(find.text('Use another email'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password'), findsOneWidget);
  });
}
