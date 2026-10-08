import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/budgets/data/budget.dart';
import 'package:hisaabchat/features/budgets/data/budgets_repository.dart';
import 'package:hisaabchat/features/categories/categories_controller.dart';

/// Budgets for a period; `null` = the current one.
final FutureProviderFamily<BudgetsOverview, String?> budgetsOverviewProvider =
    FutureProvider.family<BudgetsOverview, String?>((ref, month) async {
      ref.watch(authControllerProvider.select((auth) => auth.value?.id));
      return ref.watch(budgetsRepositoryProvider).overview(month: month);
    }, retry: (retryCount, error) => null);

typedef BudgetDetailKey = ({String id, String? month});

final FutureProviderFamily<BudgetDetail, BudgetDetailKey> budgetDetailProvider =
    FutureProvider.family<BudgetDetail, BudgetDetailKey>(
      (ref, key) => ref.watch(budgetsRepositoryProvider).detail(key.id, month: key.month),
      retry: (retryCount, error) => null,
    );

/// Month shown on the Budgets tab ("YYYY-MM"; null = current period).
class BudgetMonth extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    return null;
  }

  void show(String? month) => state = month;
}

final budgetMonthProvider = NotifierProvider<BudgetMonth, String?>(BudgetMonth.new);

/// Budget open in the desktop detail pane.
class SelectedBudget extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    return null;
  }

  void select(String? id) => state = id;
}

final selectedBudgetProvider = NotifierProvider<SelectedBudget, String?>(SelectedBudget.new);

/// Latest budget alert from a saved expense; the app shows it as a toast.
class BudgetAlerts extends Notifier<BudgetAlert?> {
  @override
  BudgetAlert? build() => null;

  void publish(List<BudgetAlert> alerts) {
    if (alerts.isNotEmpty) state = alerts.first;
  }
}

final budgetAlertsProvider = NotifierProvider<BudgetAlerts, BudgetAlert?>(BudgetAlerts.new);

/// Budget changes; refreshes budgets and categories (their budget links).
class BudgetMutations {
  BudgetMutations(this._ref);

  final Ref _ref;

  BudgetsRepository get _repo => _ref.read(budgetsRepositoryProvider);

  Future<void> create(Map<String, Object?> body) => _run(() => _repo.create(body));

  Future<void> update(String id, Map<String, Object?> changes) => _run(() => _repo.update(id, changes));

  Future<void> archive(String id) async {
    await _run(() => _repo.archive(id));
    _ref.read(selectedBudgetProvider.notifier).select(null);
  }

  Future<void> setOverride(String id, String month, int amount) => _run(() => _repo.setOverride(id, month, amount));

  Future<void> deleteOverride(String id, String month) => _run(() => _repo.deleteOverride(id, month));

  Future<void> _run(Future<void> Function() action) async {
    await action();
    invalidateBudgets(_ref);
    await _ref.read(categoriesProvider.notifier).refresh();
  }
}

/// Forget cached budget numbers (after any transaction or budget change).
void invalidateBudgets(Ref ref) {
  ref
    ..invalidate(budgetsOverviewProvider)
    ..invalidate(budgetDetailProvider);
}

final budgetMutationsProvider = Provider<BudgetMutations>(BudgetMutations.new);
