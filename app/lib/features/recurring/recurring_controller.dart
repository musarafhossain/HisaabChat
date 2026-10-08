import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/recurring/data/recurring.dart';
import 'package:hisaabchat/features/recurring/data/recurring_repository.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:hisaabchat/features/transactions/transactions_controller.dart';

/// Every recurring rule (Settings → Recurring).
final recurringRulesProvider = FutureProvider<List<RecurringRule>>((ref) async {
  ref.watch(authControllerProvider.select((auth) => auth.value?.id));
  return ref.watch(recurringRepositoryProvider).list();
}, retry: (retryCount, error) => null);

/// Home's "Due soon": pending confirmations, the next 7 days, and people's due dates.
final upcomingProvider = FutureProvider<Upcoming>((ref) async {
  final userId = ref.watch(authControllerProvider.select((auth) => auth.value?.id));
  if (userId == null) return Upcoming.empty;
  return ref.watch(recurringRepositoryProvider).upcoming();
}, retry: (retryCount, error) => null);

/// Rule changes plus Confirm/Skip; each refreshes rules, Home and balances.
class RecurringMutations {
  RecurringMutations(this._ref);

  final Ref _ref;

  RecurringRepository get _repo => _ref.read(recurringRepositoryProvider);

  Future<RecurringRule> create(Map<String, Object?> body) => _run(() => _repo.create(body));

  Future<RecurringRule> update(String id, Map<String, Object?> changes) => _run(() => _repo.update(id, changes));

  Future<void> delete(String id) => _run(() => _repo.delete(id));

  Future<Txn> confirm(PendingOccurrence occurrence, {int? amount}) => _run(
    () => _repo.confirm(occurrence.id, {'id': TxnMutations.newId(), 'amount': ?amount}),
  );

  Future<void> skip(PendingOccurrence occurrence) => _run(() => _repo.skip(occurrence.id));

  Future<T> _run<T>(Future<T> Function() action) async {
    final result = await action();
    _ref.invalidate(recurringRulesProvider);
    // A rule can add a transaction straight away (auto-add, due today).
    await _ref.read(txnMutationsProvider).refreshAfterChange();
    return result;
  }
}

final recurringMutationsProvider = Provider<RecurringMutations>(RecurringMutations.new);
