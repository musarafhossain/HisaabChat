import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/network/api_client.dart';
import 'package:hisaabchat/features/budgets/data/budget.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';

typedef TxnSaved = ({Txn txn, List<BudgetAlert> alerts});

/// Filters for `GET /transactions`.
typedef TxnQuery = ({String? accountId, String? categoryId, TxnType? type, String? q});

/// `/transactions` endpoints plus account reconcile.
class TransactionsRepository {
  TransactionsRepository(this._api);

  final ApiClient _api;

  Future<TxnPage> list(TxnQuery query, {String? cursor, int limit = 30}) async {
    final page = await _api.getWithMeta<List<dynamic>>(
      '/transactions',
      query: {
        'accountId': ?query.accountId,
        'categoryId': ?query.categoryId,
        'type': ?query.type?.api,
        if (query.q != null && query.q!.isNotEmpty) 'q': query.q,
        'cursor': ?cursor,
        'limit': limit,
      },
    );
    return (
      items: page.data.cast<Map<String, dynamic>>().map(Txn.fromJson).toList(),
      nextCursor: page.meta['nextCursor'] as String?,
      totals: TxnTotals.fromJson(page.meta['totals'] as Map<String, dynamic>?),
    );
  }

  /// Idempotent: posting an existing id returns that transaction. Also returns
  /// the budgets this expense pushed past their alert level or limit.
  Future<TxnSaved> create(Map<String, Object?> body) async {
    final json = await _api.postForBody('/transactions', body: body);
    return (
      txn: Txn.fromJson(json['data'] as Map<String, dynamic>),
      alerts: [
        for (final a in (json['budgetAlerts'] as List? ?? const []).cast<Map<String, dynamic>>())
          BudgetAlert.fromJson(a),
      ],
    );
  }

  Future<Txn> update(String id, Map<String, Object?> changes) async =>
      Txn.fromJson(await _api.patch<Map<String, dynamic>>('/transactions/$id', body: changes));

  Future<void> delete(String id) => _api.delete<Object?>('/transactions/$id');

  /// Creates an adjustment so the account matches [actualBalance]; null if it already did.
  Future<Txn?> reconcile(String accountId, int actualBalance) async {
    final data = await _api.post<Map<String, dynamic>?>(
      '/accounts/$accountId/reconcile',
      body: {'actualBalance': actualBalance},
    );
    return data == null ? null : Txn.fromJson(data);
  }
}

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.watch(apiClientProvider)),
);
