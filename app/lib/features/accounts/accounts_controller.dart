import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/data/accounts_repository.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';

@immutable
class AccountsState {
  const AccountsState({required this.all, required this.netWorth});

  final List<Account> all;

  /// Server-computed: active accounts that are included in the total.
  final int netWorth;

  List<Account> get active => all.where((a) => !a.archived).toList();
  List<Account> get archived => all.where((a) => a.archived).toList();

  Account? byId(String id) {
    for (final account in all) {
      if (account.id == id) return account;
    }
    return null;
  }
}

/// The signed-in user's accounts. Every change goes to the server and the
/// list is reloaded, so balances and net worth always match the API.
class AccountsController extends AsyncNotifier<AccountsState> {
  AccountsRepository get _repo => ref.read(accountsRepositoryProvider);

  @override
  Future<AccountsState> build() async {
    // Reload for whoever signs in next; nothing to load while signed out.
    final userId = ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    if (userId == null) return const AccountsState(all: [], netWorth: 0);
    return _load();
  }

  Future<AccountsState> _load() async {
    final page = await _repo.list();
    return AccountsState(all: page.accounts, netWorth: page.netWorth);
  }

  Future<void> refresh() async => state = await AsyncValue.guard(_load);

  Future<Account> create(Map<String, Object?> body) => _mutate(() => _repo.create(body));

  Future<Account> updateAccount(String id, Map<String, Object?> changes) => _mutate(() => _repo.update(id, changes));

  Future<Account> setArchived(String id, {required bool archived}) =>
      _mutate(() => _repo.setArchived(id, archived: archived));

  Future<void> delete(String id) => _mutate(() => _repo.delete(id));

  Future<T> _mutate<T>(Future<T> Function() action) async {
    final result = await action();
    state = AsyncData(await _load());
    return result;
  }
}

final accountsProvider = AsyncNotifierProvider<AccountsController, AccountsState>(AccountsController.new);

/// Account shown in the desktop detail pane (expanded layout only).
class SelectedAccount extends Notifier<String?> {
  @override
  String? build() {
    // Forget the selection when a different user signs in.
    ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    return null;
  }

  void select(String? id) => state = id;
}

final selectedAccountProvider = NotifierProvider<SelectedAccount, String?>(SelectedAccount.new);
