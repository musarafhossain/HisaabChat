import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/network/api_client.dart';
import 'package:hisaabchat/features/budgets/data/budget.dart';

/// `/budgets` endpoints. `month` is "YYYY-MM"; null means the current period.
class BudgetsRepository {
  BudgetsRepository(this._api);

  final ApiClient _api;

  Future<BudgetsOverview> overview({String? month}) async => BudgetsOverview.fromJson(
    await _api.get<Map<String, dynamic>>('/budgets', query: {'month': ?month}),
  );

  Future<BudgetDetail> detail(String id, {String? month}) async => BudgetDetail.fromJson(
    await _api.get<Map<String, dynamic>>('/budgets/$id', query: {'month': ?month}),
  );

  Future<void> create(Map<String, Object?> body) => _api.post<Object?>('/budgets', body: body);

  Future<void> update(String id, Map<String, Object?> changes) => _api.patch<Object?>('/budgets/$id', body: changes);

  Future<void> archive(String id) => _api.post<Object?>('/budgets/$id/archive');

  Future<void> setOverride(String id, String month, int amount) =>
      _api.put<Object?>('/budgets/$id/overrides/$month', body: {'amount': amount});

  Future<void> deleteOverride(String id, String month) => _api.delete<Object?>('/budgets/$id/overrides/$month');
}

final budgetsRepositoryProvider = Provider<BudgetsRepository>((ref) => BudgetsRepository(ref.watch(apiClientProvider)));
