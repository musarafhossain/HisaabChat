import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/presentation/account_tile.dart';
import 'package:hisaabchat/features/transactions/presentation/thread_widgets.dart';
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';

import 'helpers.dart';

FakeAccountsRepository _cash() => FakeAccountsRepository([
  const Account(
    id: 'cash',
    name: 'Cash',
    type: AccountType.cash,
    openingBalance: 500000,
    balance: 500000,
    color: Color(0xFF16A34A),
    icon: 'payments',
    includeInTotal: true,
    archived: false,
  ),
]);

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _openAccounts(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Accounts')));
  await tester.pumpAndSettle();
}

Finder _fab() => find.byType(FloatingActionButton);

void main() {
  testWidgets('the + button grows into the transaction form and shrinks back', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    final start = tester.getRect(_fab());

    await tester.tap(_fab());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    // Mid-flight the form is still clipped to a shape near the button.
    final clip = find.ancestor(of: find.byType(TxnForm), matching: find.byType(ClipRRect)).first;
    final mid = tester.getRect(clip);
    expect(mid.width, greaterThan(start.width));
    expect(mid.width, lessThan(400));
    expect(mid.contains(start.center), isTrue);

    await tester.pumpAndSettle();
    expect(tester.getRect(find.ancestor(of: find.byType(TxnForm), matching: find.byType(ClipRRect)).first).width, 400);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(TxnForm), findsNothing);
    expect(tester.getRect(_fab()), start);
  });

  testWidgets('what you typed survives the + button animation finishing', (tester) async {
    await pumpApp(tester, savedToken: 'oat', accounts: _cash());
    await tester.tap(_fab());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final field = find.descendant(of: find.byType(TxnForm), matching: find.byType(TextFormField)).first;
    await tester.enterText(field, '250');
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(TxnForm), matching: find.text('250')), findsOneWidget);
  });

  group('reduce motion', () {
    testWidgets('the form opens at once from the + button', (tester) async {
      _reduceMotion(tester);
      await pumpApp(tester, savedToken: 'oat', accounts: _cash());

      await tester.tap(_fab());
      await tester.pump();
      await tester.pump();

      // Already full size: no growing out of the button.
      final clip = find.ancestor(of: find.byType(TxnForm), matching: find.byType(ClipRRect)).first;
      expect(tester.getRect(clip).width, 400);
    });

    testWidgets('pages change at once and avatars do not fly', (tester) async {
      _reduceMotion(tester);
      await pumpApp(tester, savedToken: 'oat', accounts: _cash());
      await _openAccounts(tester);

      final heroMode = tester.widget<HeroMode>(
        find.ancestor(of: find.byType(Hero), matching: find.byType(HeroMode)).first,
      );
      expect(heroMode.enabled, isFalse);

      await tester.tap(find.widgetWithText(AccountTile, 'Cash').first);
      await tester.pump();
      await tester.pump();
      expect(find.text('Balance ₹5,000'), findsOneWidget);
    });

    testWidgets('selecting a bubble shows the check straight away', (tester) async {
      _reduceMotion(tester);
      await pumpApp(
        tester,
        savedToken: 'oat',
        accounts: _cash(),
        seed: (app) async {
          await app.txns.create({
            'type': 'EXPENSE',
            'amount': 12000,
            'accountId': 'cash',
            'categoryId': app.categories.byName('Petrol').id,
            'date': DateTime.now().toUtc().toIso8601String(),
          });
        },
      );
      await _openAccounts(tester);
      await tester.tap(find.widgetWithText(AccountTile, 'Cash').first);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Cancel selection'), findsNothing);
      await tester.longPress(find.text('−₹120'));
      await tester.pump();

      expect(find.byTooltip('Cancel selection'), findsOneWidget);
      expect(tester.widget<TxnBubble>(find.byType(TxnBubble)).selected, isTrue);
      expect(find.byIcon(AppIcons.ok), findsOneWidget);
    });
  });

  testWidgets('with motion on, selecting a bubble cross-fades to the selection bar', (tester) async {
    await pumpApp(
      tester,
      savedToken: 'oat',
      accounts: _cash(),
      seed: (app) async {
        await app.txns.create({
          'type': 'EXPENSE',
          'amount': 12000,
          'accountId': 'cash',
          'categoryId': app.categories.byName('Petrol').id,
          'date': DateTime.now().toUtc().toIso8601String(),
        });
      },
    );
    await _openAccounts(tester);
    await tester.tap(find.widgetWithText(AccountTile, 'Cash').first);
    await tester.pumpAndSettle();

    final press = await tester.startGesture(tester.getCenter(find.text('−₹120')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 50));
    // Both bars are on screen while they cross-fade.
    expect(find.byType(AppBar), findsNWidgets(2));

    await press.up();
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byTooltip('Cancel selection'), findsOneWidget);
  });

  group('source rules', () {
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

    // These check context.reduceMotion themselves before starting.
    const selfGuarded = ['ring_progress.dart', 'shake.dart', 'skeleton.dart', 'entrance.dart'];

    test('fixed animation durations go through context.motion', () {
      final offenders = [
        for (final file in files)
          if (!selfGuarded.any(file.path.endsWith) && file.readAsStringSync().contains('duration: const Duration'))
            file.path,
      ];
      expect(offenders, isEmpty);
    });

    test('bottom sheets respect reduce motion', () {
      final offenders = [
        for (final file in files)
          if (RegExp('showModalBottomSheet<').allMatches(file.readAsStringSync()).length !=
              RegExp('sheetAnimationStyle: context.sheetMotion').allMatches(file.readAsStringSync()).length)
            file.path,
      ];
      expect(offenders, isEmpty);
    });

    test('heroes go through AppHero', () {
      final offenders = [
        for (final file in files)
          if (!file.path.endsWith('entrance.dart') && RegExp(r'(?<![A-Za-z])Hero\(').hasMatch(file.readAsStringSync()))
            file.path,
      ];
      expect(offenders, isEmpty);
    });
  });
}
