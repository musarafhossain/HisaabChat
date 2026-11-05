// The whole first-run journey against a real API and database:
// register → onboarding → add an expense → budget and dashboard update.
//
// Needs the API running; see "End-to-end test" in the README for the commands.
// Unlike test/, nothing here is faked except where the login token is kept, so
// the test can't touch a session saved on this machine.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/app/app.dart';
import 'package:hisaabchat/core/storage/preferences.dart';
import 'package:hisaabchat/core/storage/token_store.dart';
import 'package:hisaabchat/features/accounts/presentation/account_tile.dart';
import 'package:hisaabchat/features/transactions/presentation/quick_composer.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _budget = 'Bike EMI + Petrol';

/// Waits for [finder] to appear. Network calls don't schedule frames, so
/// `pumpAndSettle` can't be used to wait for the server.
Future<void> _waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out after ${timeout.inSeconds}s waiting for ${finder.describeMatch(Plurality.one)}');
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await _waitFor(tester, find.text(text));
  await tester.ensureVisible(find.text(text).first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(text).first);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _fill(WidgetTester tester, String hint, String value) async {
  final field = find.widgetWithText(TextFormField, hint);
  await _waitFor(tester, field);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump(const Duration(milliseconds: 100));
}

/// Opens a section from the phone's bottom bar or the desktop rail.
Future<void> _openSection(WidgetTester tester, String label) async {
  final bottomBar = find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
  await tester.tap(bottomBar.evaluate().isNotEmpty ? bottomBar : find.byTooltip(label));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpApp(WidgetTester tester, TokenStore tokens, SharedPreferences preferences) async {
  await tester.pumpWidget(
    ProviderScope(
      // A new key rebuilds everything from the server when the app is "reopened".
      key: UniqueKey(),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        tokenStoreProvider.overrideWithValue(tokens),
      ],
      child: const HisaabChatApp(),
    ),
  );
}

/// Sets the window size, except for the phone layout on Android, which uses
/// the device's own screen and keyboard. A forced size has to ignore the
/// device's insets: they're in real pixels and would squeeze the small window.
void _setWindow(WidgetTester tester, Size window) {
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (isAndroid && window.width < 600) return;
  tester.view
    ..physicalSize = window
    ..devicePixelRatio = 1
    ..viewInsets = FakeViewPadding.zero
    ..viewPadding = FakeViewPadding.zero
    ..padding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

Future<void> _journey(WidgetTester tester, Size window) async {
  _setWindow(tester, window);

  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final tokens = MemoryTokenStore();
  final email = 'e2e-${DateTime.now().microsecondsSinceEpoch}@example.com';

  // Register.
  await _pumpApp(tester, tokens, preferences);
  await _tapText(tester, 'Get started');
  await _fill(tester, 'Your name', 'Asha Rao');
  await _fill(tester, 'Email', email);
  await _fill(tester, 'Password (at least 8 characters)', 'secret-password');
  await _fill(tester, 'Confirm password', 'secret-password');
  await _tapText(tester, 'Create account');

  // Onboarding: ₹5,000 cash and a ₹2,000 budget.
  await _waitFor(tester, find.text('Your month'));
  await _tapText(tester, 'Next');
  await _waitFor(tester, find.text('Your money'));
  await _fill(tester, 'Cash in hand', '5000');
  await _tapText(tester, 'Next');
  await _waitFor(tester, find.text('Your budgets'));
  await _tapText(tester, _budget);
  await _fill(tester, 'Monthly amount', '2000');
  await _tapText(tester, 'Finish');

  // Home starts from what onboarding saved.
  await _waitFor(tester, find.text('Total balance'));
  await _waitFor(tester, find.text('₹5,000'));
  await _waitFor(tester, find.text(_budget));
  expect(find.text('0%'), findsOneWidget);

  // Add an expense from the Cash chat. "petrol" belongs to the budget.
  await _openSection(tester, 'Accounts');
  final cash = find.widgetWithText(AccountTile, 'Cash');
  await _waitFor(tester, cash);
  await tester.tap(cash.first);
  final composer = find.descendant(of: find.byType(QuickComposer), matching: find.byType(TextField));
  await _waitFor(tester, composer);
  await tester.enterText(composer, '500 petrol');
  await _waitFor(tester, find.byTooltip('Send'));
  await tester.tap(find.byTooltip('Send'));
  await _waitFor(tester, find.text('Balance ₹4,500'));

  // Phones show the chat full screen, so leave it first.
  final back = find.byTooltip('Back');
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
    await tester.pump(const Duration(milliseconds: 500));
  }

  // The budget and the dashboard both moved.
  await _openSection(tester, 'Budgets');
  await _waitFor(tester, find.text(_budget));
  await _waitFor(tester, find.text('25%'));
  await _openSection(tester, 'Home');
  await _waitFor(tester, find.text('₹4,500'));
  await _waitFor(tester, find.text('25%'));
  await _waitFor(tester, find.text('₹500'));

  // Reopen the app with the same login: everything now comes from the server,
  // and the user goes straight to Home, not back to onboarding.
  await tester.pumpWidget(const SizedBox.shrink());
  await _pumpApp(tester, tokens, preferences);
  await _waitFor(tester, find.text('Total balance'));
  await _waitFor(tester, find.text('₹4,500'));
  await _waitFor(tester, find.text('25%'));
  expect(find.text('Your month'), findsNothing);

  // Stop timers and pending requests before the next test.
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('phone: register → onboarding → expense → budget and dashboard', (tester) async {
    await _journey(tester, const Size(400, 860));
  });

  testWidgets('desktop: register → onboarding → expense → budget and dashboard', (tester) async {
    await _journey(tester, const Size(1280, 800));
  });
}
