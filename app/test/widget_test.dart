import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/app/theme/app_theme.dart';
import 'package:hisaabchat/core/storage/preferences.dart';
import 'package:hisaabchat/features/health/connection_check_screen.dart';
import 'package:hisaabchat/features/health/health_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpConnection(WidgetTester tester, Future<HealthStatus> Function() health) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          healthProvider.overrideWith((ref) => health()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const ConnectionCheckScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Connection shows a connected status when the API is healthy', (tester) async {
    await pumpConnection(
      tester,
      () async => HealthStatus(status: 'ok', database: 'up', serverTime: DateTime.utc(2026, 10, 8, 14)),
    );

    expect(find.text('Connection'), findsOneWidget);
    expect(find.text('Connected to the API'), findsOneWidget);
  });

  testWidgets('Connection offers a retry when the API is unreachable', (tester) async {
    await pumpConnection(tester, () async => throw Exception('offline'));

    expect(find.text('Can’t reach the API'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
