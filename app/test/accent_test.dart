import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/app/theme/accent.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/features/auth/data/app_user.dart';

import 'helpers.dart';

/// The app's current primary color.
Color _primary(WidgetTester tester) => Theme.of(tester.element(find.byType(Scaffold).first)).colorScheme.primary;

Future<void> _openAppearance(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Appearance'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('teal is the default accent', (tester) async {
    await pumpApp(tester, savedToken: 'oat');
    expect(_primary(tester), AccentColor.teal.light);
  });

  testWidgets('picking a color recolors the app and saves it to the profile', (tester) async {
    final app = await pumpApp(tester, savedToken: 'oat');
    await _openAppearance(tester);

    expect(find.text('Color · Teal'), findsOneWidget);
    expect(find.byTooltip('Purple'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'color$')), findsNWidgets(AccentColor.values.length));

    await tester.tap(find.byTooltip('Purple'));
    await tester.pumpAndSettle();

    expect(find.text('Color · Purple'), findsOneWidget);
    expect(_primary(tester), AccentColor.purple.light);
    expect(app.repo.lastProfileUpdate, {'accentColor': 'PURPLE'});
  });

  testWidgets('signing in adopts the color saved on the profile', (tester) async {
    final repo = FakeAuthRepository()
      ..user = copyUser(testUser, accent: AccentColor.blue, onboardedAt: DateTime.utc(2026));
    await pumpApp(tester, savedToken: 'oat', repo: repo);
    expect(_primary(tester), AccentColor.blue.light);
  });

  test('every accent keeps money colors fixed and is readable on its background', () {
    for (final accent in AccentColor.values) {
      final light = AppColors.lightFor(accent);
      final dark = AppColors.darkFor(accent);
      expect(light.income, const Color(0xFF1DAA61), reason: accent.label);
      expect(light.expense, const Color(0xFFE53935), reason: accent.label);
      expect(dark.transfer, const Color(0xFF53BDEB), reason: accent.label);

      // Buttons use white text on the light shade and dark text on the dark shade.
      expect(_contrast(accent.light, Colors.white), greaterThanOrEqualTo(3), reason: '${accent.label} light');
      expect(
        _contrast(accent.dark, const Color(0xFF0B141A)),
        greaterThanOrEqualTo(4.5),
        reason: '${accent.label} dark',
      );
    }
  });

  test('profile accent parses with a teal fallback', () {
    final user = AppUser.fromJson(const {'id': 'u', 'email': 'a@b.c', 'accentColor': 'PINK'});
    expect(user.accent, AccentColor.pink);
    expect(AccentColor.fromApi('NOPE'), AccentColor.teal);
    expect(AccentColor.fromApi(null), AccentColor.teal);
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}
