import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/network/api_client.dart';
import 'package:intl/intl.dart';

/// A file built by the server: its name and contents.
typedef ExportFile = ({String fileName, Uint8List bytes, String mimeType});

/// `GET /export/*` downloads (docs/02-TRD.md §4).
class ExportRepository {
  ExportRepository(this._api);

  final ApiClient _api;

  static final _day = DateFormat('yyyy-MM-dd');

  /// Transactions as CSV, oldest first. [from] and [to] are local days, both
  /// included; leave them out for everything.
  Future<ExportFile> transactionsCsv({DateTime? from, DateTime? to, String? accountId, String? personId}) async {
    final bytes = await _api.getBytes(
      '/export/transactions.csv',
      query: {
        if (from != null) 'from': _day.format(from),
        if (to != null) 'to': _day.format(to),
        'accountId': ?accountId,
        'personId': ?personId,
      },
    );
    return (fileName: csvFileName(from: from, to: to), bytes: bytes, mimeType: 'text/csv');
  }

  /// Everything (accounts, categories, budgets, people, transactions,
  /// recurring) as one JSON backup.
  Future<ExportFile> backupJson() async {
    final bytes = await _api.getBytes('/export/all.json');
    return (
      fileName: 'hisaabchat-backup-${_day.format(DateTime.now())}.json',
      bytes: bytes,
      mimeType: 'application/json',
    );
  }

  /// Same names as the server's `Content-Disposition`.
  static String csvFileName({DateTime? from, DateTime? to}) {
    final range = switch ((from, to)) {
      (final f?, final t?) => '${_day.format(f)}-to-${_day.format(t)}',
      (final f?, null) => 'from-${_day.format(f)}',
      (null, final t?) => 'to-${_day.format(t)}',
      (null, null) => 'all',
    };
    return 'hisaabchat-transactions-$range.csv';
  }
}

final exportRepositoryProvider = Provider<ExportRepository>((ref) => ExportRepository(ref.watch(apiClientProvider)));
