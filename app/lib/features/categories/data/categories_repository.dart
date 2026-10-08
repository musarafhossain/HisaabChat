import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/network/api_client.dart';
import 'package:hisaabchat/features/categories/data/category.dart';

/// `/categories` endpoints.
class CategoriesRepository {
  CategoriesRepository(this._api);

  final ApiClient _api;

  /// All categories, including archived ones (pickers filter them out).
  Future<List<TxnCategory>> list() async {
    final data = await _api.get<List<dynamic>>('/categories', query: {'includeArchived': true});
    return data.cast<Map<String, dynamic>>().map(TxnCategory.fromJson).toList();
  }

  Future<TxnCategory> create(Map<String, Object?> body) async =>
      TxnCategory.fromJson(await _api.post<Map<String, dynamic>>('/categories', body: body));

  Future<TxnCategory> update(String id, Map<String, Object?> changes) async =>
      TxnCategory.fromJson(await _api.patch<Map<String, dynamic>>('/categories/$id', body: changes));

  Future<TxnCategory> setArchived(String id, {required bool archived}) async => TxnCategory.fromJson(
    await _api.post<Map<String, dynamic>>('/categories/$id/${archived ? 'archive' : 'unarchive'}'),
  );
}

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(ref.watch(apiClientProvider)),
);
