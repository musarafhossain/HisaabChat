import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/people/data/people_repository.dart';
import 'package:hisaabchat/features/people/data/person.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:hisaabchat/features/transactions/transactions_controller.dart';

/// Everyone you lend to or borrow from, with balances.
class PeopleController extends AsyncNotifier<PeopleState> {
  PeopleRepository get _repo => ref.read(peopleRepositoryProvider);

  @override
  Future<PeopleState> build() async {
    final userId = ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    if (userId == null) return const PeopleState(people: [], youGet: 0, youOwe: 0);
    return _repo.list();
  }

  Future<void> refresh() async => state = await AsyncValue.guard(_repo.list);

  Future<Person> create(Map<String, Object?> body) => _mutate(() => _repo.create(body));

  Future<Person> updatePerson(String id, Map<String, Object?> changes) => _mutate(() => _repo.update(id, changes));

  Future<Person> setArchived(String id, {required bool archived}) =>
      _mutate(() => _repo.setArchived(id, archived: archived));

  /// Settle up: records the COLLECT/REPAY and refreshes balances everywhere.
  Future<Txn> settle(String id, {required String accountId, int? amount}) async {
    final txn = await _repo.settle(id, accountId: accountId, amount: amount, txnId: TxnMutations.newId());
    await ref.read(txnMutationsProvider).refreshAfterChange();
    return txn;
  }

  Future<T> _mutate<T>(Future<T> Function() action) async {
    final result = await action();
    await refresh();
    return result;
  }
}

final peopleProvider = AsyncNotifierProvider<PeopleController, PeopleState>(PeopleController.new);

/// Person open in the desktop detail pane.
class SelectedPerson extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    return null;
  }

  void select(String? id) => state = id;
}

final selectedPersonProvider = NotifierProvider<SelectedPerson, String?>(SelectedPerson.new);
