import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/app/router.dart';
import 'package:hisaabchat/core/navigation/back_navigation.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/presentation/account_tile.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_form.dart';
import 'package:hisaabchat/features/people/presentation/people_widgets.dart';
import 'package:hisaabchat/features/people/presentation/person_thread.dart';
import 'package:hisaabchat/features/recurring/presentation/recurring_screen.dart';
import 'package:hisaabchat/features/transactions/presentation/account_thread.dart';
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';

import 'helpers.dart';

FakeAccountsRepository _cash() => FakeAccountsRepository([
  const Account(
    id: 'cash',
    name: 'Cash',
    type: AccountType.cash,
    openingBalance: 100000,
    balance: 100000,
    color: Color(0xFF16A34A),
    icon: 'payments',
    includeInTotal: true,
    archived: false,
  ),
]);

/// Android's Back button (the path every press takes on the phone).
/// Returns how many times the app asked the OS to close.
Future<int> _pressBack(WidgetTester tester) async {
  var exits = 0;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'SystemNavigator.pop') exits++;
    return null;
  });
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
  return exits;
}

Future<void> _menu(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip('More options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Back closes the New transaction form, not the app', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    await tester.tap(find.byTooltip('New transaction'));
    await tester.pumpAndSettle();
    expect(find.byType(TxnForm), findsOneWidget);

    expect(await _pressBack(tester), 0);
    expect(find.byType(TxnForm), findsNothing);
    expect(find.text('Total balance'), findsOneWidget); // still on Home
  });

  testWidgets('Back closes a bottom sheet, then an account chat, one at a time', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Budgets')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New budget'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetForm), findsOneWidget);
    expect(await _pressBack(tester), 0);
    expect(find.byType(BudgetForm), findsNothing);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Accounts')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AccountTile, 'Cash').first);
    await tester.pumpAndSettle();
    expect(find.byType(AccountThreadScreen), findsOneWidget);
    expect(await _pressBack(tester), 0);
    expect(find.byType(AccountThreadScreen), findsNothing);
    expect(find.widgetWithText(AccountTile, 'Cash'), findsWidgets);
  });

  testWidgets('Back closes a person’s chat and a Settings page', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: (a) async => a.people.add('Amit'));
    await _menu(tester, 'People');
    await tester.tap(find.widgetWithText(PersonTile, 'Amit'));
    await tester.pumpAndSettle();
    expect(find.byType(PersonThreadScreen), findsOneWidget);
    expect(await _pressBack(tester), 0);
    expect(find.byType(PersonThreadScreen), findsNothing);
    expect(find.widgetWithText(PersonTile, 'Amit'), findsOneWidget);

    // Back on the People section itself returns to Home instead of leaving.
    expect(await _pressBack(tester), 0);
    expect(find.text('Total balance'), findsOneWidget);

    await _menu(tester, 'Settings');
    await tester.tap(find.text('Recurring'));
    await tester.pumpAndSettle();
    expect(find.byType(RecurringScreen), findsOneWidget);
    expect(await _pressBack(tester), 0);
    expect(find.byType(RecurringScreen), findsNothing);
  });

  testWidgets('Back on another tab goes to Home first, then leaves the app', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Budgets')));
    await tester.pumpAndSettle();

    expect(await _pressBack(tester), 0);
    expect(find.text('Total balance'), findsOneWidget);
    expect(await _pressBack(tester), 1);
  });

  testWidgets('Back on Home with nothing open leaves the app', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    expect(await _pressBack(tester), 1);
  });

  // ───────────── Windows (and web): Esc and the mouse's back button ─────────────

  testWidgets('Esc closes the full-screen New transaction form', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    await tester.tap(find.byTooltip('New transaction'));
    await tester.pumpAndSettle();
    expect(find.byType(TxnForm), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(TxnForm), findsNothing);
    expect(find.text('Total balance'), findsOneWidget);
  });

  testWidgets('the mouse back button closes a chat, then goes to Home', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash(), seed: (a) async => a.people.add('Amit'));
    await _menu(tester, 'People');
    await tester.tap(find.widgetWithText(PersonTile, 'Amit'));
    await tester.pumpAndSettle();
    expect(find.byType(PersonThreadScreen), findsOneWidget);

    Future<void> mouseBack() async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kBackMouseButton);
      await mouse.down(const Offset(200, 400));
      await mouse.up();
      await tester.pumpAndSettle();
    }

    await mouseBack();
    expect(find.byType(PersonThreadScreen), findsNothing);
    expect(find.widgetWithText(PersonTile, 'Amit'), findsOneWidget);

    await mouseBack();
    expect(find.text('Total balance'), findsOneWidget);
  });

  // ───────────── Web: the browser's Back button ─────────────

  testWidgets('web: browser Back closes an open form instead of changing the page', (tester) async {
    final pushed = <Map<Object?, Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.navigation, (call) async {
      if (call.method == 'routeInformationUpdated') pushed.add(call.arguments as Map<Object?, Object?>);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.navigation, null));

    var historyBacks = 0;
    Future<void> browserBack(String location) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.navigation.name,
        SystemChannels.navigation.codec.encodeMethodCall(
          MethodCall('pushRouteInformation', {'location': location, 'state': null}),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    late WebModalHistory history;
    await pumpApp(
      tester,
      savedToken: 'oat',
      accounts: _cash(),
      overrides: [
        webModalHistoryProvider.overrideWith((ref) {
          history = WebModalHistory(enabled: true, historyBack: () => historyBacks++);
          WidgetsBinding.instance.addObserver(history);
          ref.onDispose(() => WidgetsBinding.instance.removeObserver(history));
          return history;
        }),
      ],
    );

    // Opening the form adds a history entry for the same page.
    pushed.clear();
    await tester.tap(find.byTooltip('New transaction'));
    await tester.pumpAndSettle();
    expect(find.byType(TxnForm), findsOneWidget);
    expect(pushed.where((p) => p['replace'] == false && '${p['uri']}' == '/dashboard'), isNotEmpty);

    // Browser Back: the form closes, the page stays, nothing else is undone.
    await browserBack('/dashboard');
    expect(find.byType(TxnForm), findsNothing);
    expect(find.text('Total balance'), findsOneWidget);
    expect(historyBacks, 0);

    // Closing it with × instead drops its history entry; the resulting
    // browser event is ignored rather than taken as another Back.
    await tester.tap(find.byTooltip('New transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(historyBacks, 1);
    await browserBack('/dashboard');
    expect(find.text('Total balance'), findsOneWidget);
    expect(find.byType(TxnForm), findsNothing);

    // With nothing open, browser Back is a normal page change.
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Budgets')));
    await tester.pumpAndSettle();
    await browserBack('/dashboard');
    expect(find.text('Total balance'), findsOneWidget);
  });
}
