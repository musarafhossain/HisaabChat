import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/network/api_client.dart';
import 'package:hisaabchat/features/people/data/person.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';

/// `/people` endpoints (lend & borrow).
class PeopleRepository {
  PeopleRepository(this._api);

  final ApiClient _api;

  Future<PeopleState> list() async {
    final page = await _api.getWithMeta<List<dynamic>>('/people', query: {'includeArchived': true});
    return PeopleState(
      people: page.data.cast<Map<String, dynamic>>().map(Person.fromJson).toList(),
      youGet: (page.meta['youGet'] as num?)?.toInt() ?? 0,
      youOwe: (page.meta['youOwe'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Person> create(Map<String, Object?> body) async =>
      Person.fromJson(await _api.post<Map<String, dynamic>>('/people', body: body));

  Future<Person> update(String id, Map<String, Object?> changes) async =>
      Person.fromJson(await _api.patch<Map<String, dynamic>>('/people/$id', body: changes));

  Future<Person> setArchived(String id, {required bool archived}) async => Person.fromJson(
    await _api.post<Map<String, dynamic>>('/people/$id/${archived ? 'archive' : 'unarchive'}'),
  );

  /// Records what squares you up (a COLLECT or REPAY); [amount] defaults to all of it.
  Future<Txn> settle(String id, {required String accountId, required String txnId, int? amount}) async => Txn.fromJson(
    await _api.post<Map<String, dynamic>>(
      '/people/$id/settle',
      body: {'id': txnId, 'accountId': accountId, 'amount': ?amount},
    ),
  );
}

final peopleRepositoryProvider = Provider<PeopleRepository>((ref) => PeopleRepository(ref.watch(apiClientProvider)));
