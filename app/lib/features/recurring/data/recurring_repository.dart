import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/network/api_client.dart';
import 'package:hisaabchat/features/recurring/data/recurring.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';

/// `/recurring` endpoints: rules, what's due soon, Confirm and Skip.
class RecurringRepository {
  RecurringRepository(this._api);

  final ApiClient _api;

  Future<List<RecurringRule>> list() async {
    final data = await _api.get<List<dynamic>>('/recurring');
    return data.cast<Map<String, dynamic>>().map(RecurringRule.fromJson).toList();
  }

  Future<RecurringRule> create(Map<String, Object?> body) async =>
      RecurringRule.fromJson(await _api.post<Map<String, dynamic>>('/recurring', body: body));

  Future<RecurringRule> update(String id, Map<String, Object?> changes) async =>
      RecurringRule.fromJson(await _api.patch<Map<String, dynamic>>('/recurring/$id', body: changes));

  Future<void> delete(String id) => _api.delete<Object?>('/recurring/$id');

  Future<Upcoming> upcoming({int days = 7}) async =>
      Upcoming.fromJson(await _api.get<Map<String, dynamic>>('/recurring/upcoming', query: {'days': days}));

  /// Adds the transaction for a pending occurrence (optionally adjusted).
  Future<Txn> confirm(String occurrenceId, Map<String, Object?> body) async =>
      Txn.fromJson(await _api.post<Map<String, dynamic>>('/recurring/occurrences/$occurrenceId/confirm', body: body));

  Future<void> skip(String occurrenceId) => _api.post<Object?>('/recurring/occurrences/$occurrenceId/skip');
}

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(ref.watch(apiClientProvider)),
);
