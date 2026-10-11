import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/platform/file_saver.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/export/data/export_repository.dart';
import 'package:hisaabchat/features/export/presentation/export_screen.dart';

import 'helpers.dart';

/// Records what was asked for instead of calling the server.
class FakeExportRepository implements ExportRepository {
  final csvCalls = <({DateTime? from, DateTime? to, String? accountId, String? personId})>[];
  int backupCalls = 0;
  ApiException? error;

  @override
  Future<ExportFile> transactionsCsv({DateTime? from, DateTime? to, String? accountId, String? personId}) async {
    if (error != null) throw error!;
    csvCalls.add((from: from, to: to, accountId: accountId, personId: personId));
    return (
      fileName: ExportRepository.csvFileName(from: from, to: to),
      bytes: Uint8List.fromList(utf8.encode('Date,Type\n')),
      mimeType: 'text/csv',
    );
  }

  @override
  Future<ExportFile> backupJson() async {
    backupCalls++;
    return (
      fileName: 'hisaabchat-backup.json',
      bytes: Uint8List.fromList(utf8.encode('{}')),
      mimeType: 'application/json',
    );
  }
}

class FakeFileSaver implements FileSaver {
  FakeFileSaver([this.outcome = SaveOutcome.saved]);

  SaveOutcome outcome;
  final saved = <String>[];

  @override
  Future<SaveOutcome> save({required String fileName, required Uint8List bytes, required String mimeType}) async {
    saved.add(fileName);
    return outcome;
  }
}

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

Future<({FakeExportRepository exports, FakeFileSaver saver})> _pump(
  WidgetTester tester, {
  SaveOutcome outcome = SaveOutcome.saved,
}) async {
  final exports = FakeExportRepository();
  final saver = FakeFileSaver(outcome);
  await pumpApp(
    tester,
    savedToken: 'oat',
    accounts: _cash(),
    overrides: [
      exportRepositoryProvider.overrideWithValue(exports),
      fileSaverProvider.overrideWithValue(saver),
    ],
  );
  return (exports: exports, saver: saver);
}

Future<void> _openExportScreen(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Export data'));
  await tester.pumpAndSettle();
}

void main() {
  group('exportRangeDates', () {
    test('months start on day 1 by default', () {
      final today = DateTime(2026, 10, 11);
      expect(exportRangeDates(ExportRange.thisMonth, today: today), (
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 31),
      ));
      expect(exportRangeDates(ExportRange.lastMonth, today: today), (
        from: DateTime(2026, 9),
        to: DateTime(2026, 9, 30),
      ));
      expect(exportRangeDates(ExportRange.thisYear, today: today), (
        from: DateTime(2026),
        to: DateTime(2026, 12, 31),
      ));
      expect(exportRangeDates(ExportRange.allTime, today: today), (from: null, to: null));
    });

    test('follow the month start day, across the new year', () {
      // Months start on the 5th; 3 Jan is still in the period that began 5 Dec.
      final today = DateTime(2027, 1, 3);
      expect(exportRangeDates(ExportRange.thisMonth, today: today, monthStartDay: 5), (
        from: DateTime(2026, 12, 5),
        to: DateTime(2027, 1, 4),
      ));
      expect(exportRangeDates(ExportRange.lastMonth, today: today, monthStartDay: 5), (
        from: DateTime(2026, 11, 5),
        to: DateTime(2026, 12, 4),
      ));
    });
  });

  test('CSV file names match the server', () {
    expect(ExportRepository.csvFileName(), 'hisaabchat-transactions-all.csv');
    expect(
      ExportRepository.csvFileName(from: DateTime(2026, 10), to: DateTime(2026, 10, 31)),
      'hisaabchat-transactions-2026-10-01-to-2026-10-31.csv',
    );
  });

  testWidgets('Settings → Export data: CSV for this month, all time, and a backup', (tester) async {
    final app = await _pump(tester);
    await _openExportScreen(tester);
    expect(find.byType(ExportScreen), findsOneWidget);

    // This month is picked to start with.
    await tester.tap(find.text('Export CSV'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(app.exports.csvCalls.single.from, DateTime(now.year, now.month));
    expect(app.exports.csvCalls.single.to, DateTime(now.year, now.month + 1, 0));
    expect(app.saver.saved.single, startsWith('hisaabchat-transactions-'));
    expect(find.text('Saved ${app.saver.saved.single}'), findsOneWidget);

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(find.text('Every transaction you’ve added'), findsOneWidget);
    await tester.tap(find.text('Export CSV'));
    await tester.pumpAndSettle();
    expect(app.exports.csvCalls.last.from, isNull);
    expect(app.saver.saved.last, 'hisaabchat-transactions-all.csv');

    await tester.tap(find.text('Export backup'));
    await tester.pumpAndSettle();
    expect(app.exports.backupCalls, 1);
    expect(app.saver.saved.last, 'hisaabchat-backup.json');
  });

  testWidgets('a cancelled Save As shows nothing; a server error shows a toast', (tester) async {
    final app = await _pump(tester, outcome: SaveOutcome.cancelled);
    await _openExportScreen(tester);

    await tester.tap(find.text('Export CSV'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved'), findsNothing);

    app.exports.error = const ApiException(message: 'Waiting for network…', isNetworkError: true);
    await tester.tap(find.text('Export CSV'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for network…'), findsOneWidget);
  });

  testWidgets('Custom asks for dates before it can export', (tester) async {
    final app = await _pump(tester);
    await _openExportScreen(tester);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Export transactions from'), findsOneWidget); // the date range picker
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Pick the dates'), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(find.widgetWithText(FilledButton, 'Export CSV'));
    expect(button.onPressed, isNull);
    expect(app.exports.csvCalls, isEmpty);
  });

  testWidgets('an account’s menu exports just that account', (tester) async {
    final app = await _pump(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Accounts')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export CSV'));
    await tester.pumpAndSettle();
    expect(app.exports.csvCalls.single.accountId, 'cash');
    expect(app.exports.csvCalls.single.from, isNull);
    expect(app.saver.saved.single, 'hisaabchat-transactions-all.csv');
  });
}
