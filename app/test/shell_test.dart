import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';

import 'helpers.dart';

void main() {
  testWidgets('phones get the WhatsApp bottom bar with four tabs', (tester) async {
    await pumpApp(tester, savedToken: 'oat_saved');

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('HisaabChat'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Accounts')));
    await tester.pumpAndSettle();
    expect(find.text('No accounts yet'), findsOneWidget);
    expect(find.byTooltip('New account'), findsOneWidget);
    // One pane on phones: no desktop detail pane.
    expect(find.byType(EmptyDetailPane), findsNothing);
  });

  testWidgets('wide windows get the rail and list + detail panes', (tester) async {
    await pumpApp(tester, savedToken: 'oat_saved', size: const Size(1400, 900));

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Accounts'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);

    await tester.tap(find.byTooltip('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('No accounts yet'), findsOneWidget);
    expect(find.byType(EmptyDetailPane), findsOneWidget);
    expect(find.text('Select an account to see its transactions'), findsOneWidget);
  });

  testWidgets('Settings → Appearance switches the theme and saves it to the profile', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat_saved', size: const Size(1400, 900));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final app0 = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app0.themeMode, ThemeMode.dark);
    expect(app.repo.lastProfileUpdate, {'theme': 'DARK'});
  });
}
