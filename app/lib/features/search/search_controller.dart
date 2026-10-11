import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:hisaabchat/features/transactions/data/transactions_repository.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';

/// How many transactions the search screen shows (newest first).
const searchTxnLimit = 40;

/// Transactions matching a search: note, category, account, person or amount
/// (matched on the server, so it covers everything, not just what's loaded).
final FutureProviderFamily<List<Txn>, String> searchTxnsProvider = FutureProvider.family<List<Txn>, String>(
  (ref, q) async {
    final page = await ref.watch(transactionsRepositoryProvider).list((
      accountId: null,
      categoryId: null,
      personId: null,
      type: null,
      q: q,
      from: null,
      to: null,
    ), limit: searchTxnLimit);
    return page.items;
  },
  retry: (retryCount, error) => null,
);
