import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/network/api_client.dart';
import 'package:hisaabchat/features/reports/data/report.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';

/// `/dashboard` and `/reports` endpoints. `month` is "YYYY-MM"; null means
/// the current period.
class ReportsRepository {
  ReportsRepository(this._api);

  final ApiClient _api;

  Future<Dashboard> dashboard({String? month}) async =>
      Dashboard.fromJson(await _api.get<Map<String, dynamic>>('/dashboard', query: {'month': ?month}));

  Future<CategoryReport> byCategory({
    required TxnType type,
    String? month,
  }) async => CategoryReport.fromJson(
    await _api.get<Map<String, dynamic>>('/reports/categories', query: {'type': type.api, 'month': ?month}),
  );

  Future<List<TrendPoint>> trend({int months = 6, String? month}) async {
    final data = await _api.get<List<dynamic>>('/reports/trend', query: {'months': months, 'month': ?month});
    return [for (final p in data.cast<Map<String, dynamic>>()) TrendPoint.fromJson(p)];
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) => ReportsRepository(ref.watch(apiClientProvider)));
