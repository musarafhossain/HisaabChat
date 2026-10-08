import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/network/api_client.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';

typedef AccountsPage = ({List<Account> accounts, int netWorth});

/// `/accounts` endpoints (docs/02-TRD.md §4.2).
class AccountsRepository {
  AccountsRepository(this._api);

  final ApiClient _api;

  /// All accounts including archived ones, plus the server-computed net worth.
  Future<AccountsPage> list() async {
    final page = await _api.getWithMeta<List<dynamic>>('/accounts', query: {'includeArchived': true});
    return (
      accounts: page.data.cast<Map<String, dynamic>>().map(Account.fromJson).toList(),
      netWorth: (page.meta['netWorth'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Account> create(Map<String, Object?> body) async =>
      Account.fromJson(await _api.post<Map<String, dynamic>>('/accounts', body: body));

  Future<Account> update(String id, Map<String, Object?> changes) async =>
      Account.fromJson(await _api.patch<Map<String, dynamic>>('/accounts/$id', body: changes));

  Future<Account> setArchived(String id, {required bool archived}) async => Account.fromJson(
    await _api.post<Map<String, dynamic>>('/accounts/$id/${archived ? 'archive' : 'unarchive'}'),
  );

  Future<void> delete(String id) => _api.delete<Object?>('/accounts/$id');
}

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(ref.watch(apiClientProvider)),
);
