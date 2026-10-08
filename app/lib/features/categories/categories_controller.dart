import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/categories/data/categories_repository.dart';
import 'package:hisaabchat/features/categories/data/category.dart';

/// The user's categories (all, including archived), in display order.
class CategoriesController extends AsyncNotifier<List<TxnCategory>> {
  CategoriesRepository get _repo => ref.read(categoriesRepositoryProvider);

  @override
  Future<List<TxnCategory>> build() async {
    final userId = ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    if (userId == null) return const [];
    return _repo.list();
  }

  Future<void> refresh() async => state = await AsyncValue.guard(_repo.list);

  Future<TxnCategory> create(Map<String, Object?> body) => _mutate(() => _repo.create(body));

  Future<TxnCategory> updateCategory(String id, Map<String, Object?> changes) =>
      _mutate(() => _repo.update(id, changes));

  Future<TxnCategory> setArchived(String id, {required bool archived}) =>
      _mutate(() => _repo.setArchived(id, archived: archived));

  Future<T> _mutate<T>(Future<T> Function() action) async {
    final result = await action();
    state = AsyncData(await _repo.list());
    return result;
  }
}

final categoriesProvider = AsyncNotifierProvider<CategoriesController, List<TxnCategory>>(CategoriesController.new);

extension CategoryLists on List<TxnCategory> {
  /// Active categories of one type, for pickers.
  List<TxnCategory> activeOf(CategoryType type) => where((c) => c.type == type && !c.archived).toList();

  TxnCategory? byId(String? id) {
    if (id == null) return null;
    for (final category in this) {
      if (category.id == id) return category;
    }
    return null;
  }
}
