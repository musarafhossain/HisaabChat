import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/budgets/budgets_controller.dart';
import 'package:hisaabchat/features/transactions/data/transactions_repository.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:uuid/uuid.dart';

// ───────────────────────── Pending sends (optimistic bubbles) ─────────────────────────

enum PendingStatus { sending, failed }

/// A transaction typed in a composer that the server hasn't confirmed yet.
@immutable
class PendingTxn {
  const PendingTxn({required this.id, required this.body, required this.preview, required this.status});

  final String id;

  /// The POST body (includes [id], so a retry is idempotent).
  final Map<String, Object?> body;

  /// How the bubble looks until the server answers.
  final Txn preview;
  final PendingStatus status;

  PendingTxn withStatus(PendingStatus status) => PendingTxn(id: id, body: body, preview: preview, status: status);
}

class PendingTxns extends Notifier<List<PendingTxn>> {
  @override
  List<PendingTxn> build() {
    ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    return const [];
  }

  void add(PendingTxn pending) => state = [...state, pending];

  void setStatus(String id, PendingStatus status) =>
      state = [for (final p in state) p.id == id ? p.withStatus(status) : p];

  void remove(String id) => state = state.where((p) => p.id != id).toList();
}

final pendingTxnsProvider = NotifierProvider<PendingTxns, List<PendingTxn>>(PendingTxns.new);

// ───────────────────────── Mutations ─────────────────────────

/// Every transaction change goes through here, so balances, account threads
/// and the transactions list all refresh together.
class TxnMutations {
  TxnMutations(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  TransactionsRepository get _repo => _ref.read(transactionsRepositoryProvider);

  /// New client-side id (UUID v7, time-ordered).
  static String newId() => _uuid.v7();

  Future<Txn> create(Map<String, Object?> body) async {
    final saved = await _repo.create({'id': newId(), ...body});
    await _afterChange();
    _ref.read(budgetAlertsProvider.notifier).publish(saved.alerts);
    return saved.txn;
  }

  Future<Txn> update(String id, Map<String, Object?> changes) async {
    final txn = await _repo.update(id, changes);
    await _afterChange();
    return txn;
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await _afterChange();
  }

  /// Re-creates a deleted transaction with the same id (SnackBar "Undo").
  Future<Txn> restore(Txn txn) async {
    final restored = await _repo.create(txn.toCreateBody());
    await _afterChange();
    return restored.txn;
  }

  Future<Txn?> reconcile(String accountId, int actualBalance) async {
    final adjustment = await _repo.reconcile(accountId, actualBalance);
    await _afterChange();
    return adjustment;
  }

  /// Chat-style send: the bubble appears immediately with a clock, turns
  /// into ✓ when saved, or ⚠ (tap to retry) when it fails.
  Future<void> send(PendingTxn pending) async {
    final store = _ref.read(pendingTxnsProvider.notifier);
    if (_ref.read(pendingTxnsProvider).any((p) => p.id == pending.id)) {
      store.setStatus(pending.id, PendingStatus.sending);
    } else {
      store.add(pending);
    }
    try {
      final saved = await _repo.create(pending.body);
      await _afterChange();
      store.remove(pending.id);
      _ref.read(budgetAlertsProvider.notifier).publish(saved.alerts);
    } on ApiException {
      store.setStatus(pending.id, PendingStatus.failed);
    }
  }

  Future<void> _afterChange() async {
    _ref
      ..invalidate(accountThreadProvider)
      ..invalidate(transactionsListProvider);
    invalidateBudgets(_ref);
    await _ref.read(accountsProvider.notifier).refresh();
  }
}

final txnMutationsProvider = Provider<TxnMutations>(TxnMutations.new);

// ───────────────────────── Paginated lists ─────────────────────────

@immutable
class TxnListState {
  const TxnListState({required this.items, required this.nextCursor, required this.totals, this.loadingMore = false});

  final List<Txn> items;
  final String? nextCursor;
  final TxnTotals totals;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  TxnListState copyWith({List<Txn>? items, String? nextCursor, bool clearCursor = false, bool? loadingMore}) =>
      TxnListState(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        totals: totals,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Shared keyset pagination for a [TxnQuery].
abstract class _PagedTxns extends AsyncNotifier<TxnListState> {
  TxnQuery get query;
  int get pageSize => 40;

  TransactionsRepository get _repo => ref.read(transactionsRepositoryProvider);

  @override
  Future<TxnListState> build() async {
    final userId = ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    if (userId == null) return const TxnListState(items: [], nextCursor: null, totals: TxnTotals());
    final page = await _repo.list(query, limit: pageSize);
    return TxnListState(items: page.items, nextCursor: page.nextCursor, totals: page.totals);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await _repo.list(query, cursor: current.nextCursor, limit: pageSize);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          loadingMore: false,
        ),
      );
    } on ApiException {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

/// One account's "chat": its transactions, newest first.
class AccountThreadController extends _PagedTxns {
  AccountThreadController(this.accountId);

  final String accountId;

  @override
  TxnQuery get query => (accountId: accountId, categoryId: null, type: null, q: null, from: null, to: null);
}

final AsyncNotifierProviderFamily<AccountThreadController, TxnListState, String> accountThreadProvider =
    AsyncNotifierProvider.family<AccountThreadController, TxnListState, String>(
      AccountThreadController.new,
    );

/// Filters for the Transactions tab.
typedef TxnFilter = ({TxnType? type, String q});

/// The Transactions tab, for one filter combination.
class TransactionsListController extends _PagedTxns {
  TransactionsListController(this.filter);

  final TxnFilter filter;

  @override
  TxnQuery get query => (accountId: null, categoryId: null, type: filter.type, q: filter.q, from: null, to: null);
}

final AsyncNotifierProviderFamily<TransactionsListController, TxnListState, TxnFilter> transactionsListProvider =
    AsyncNotifierProvider.family<TransactionsListController, TxnListState, TxnFilter>(
      TransactionsListController.new,
    );
