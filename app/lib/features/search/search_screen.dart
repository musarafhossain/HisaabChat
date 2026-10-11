import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/load_more.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/presentation/account_tile.dart';
import 'package:hisaabchat/features/budgets/budgets_controller.dart';
import 'package:hisaabchat/features/budgets/data/budget.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_widgets.dart';
import 'package:hisaabchat/features/people/data/person.dart';
import 'package:hisaabchat/features/people/people_controller.dart';
import 'package:hisaabchat/features/people/presentation/people_widgets.dart';
import 'package:hisaabchat/features/transactions/data/transactions_repository.dart';
import 'package:hisaabchat/features/transactions/presentation/transactions_section.dart' show TransactionTile;
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';
import 'package:hisaabchat/features/transactions/transactions_controller.dart';

/// Search everything (`/search`): opened from the search icon on phones,
/// the rail on desktop, or Ctrl+F. Accounts, people and budgets are matched
/// by name in the app; transactions on the server (note, category, account,
/// person or amount).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _text = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _clear() {
    _debounce?.cancel();
    _text.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _text,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(fontSize: 17, color: colors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Search everything',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        actions: [
          if (_text.text.isNotEmpty)
            IconButton(tooltip: 'Clear search', icon: const Icon(AppIcons.close), onPressed: _clear),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _query.isEmpty
              ? const EmptyState(
                  icon: AppIcons.search,
                  title: 'Search HisaabChat',
                  message:
                      'Find transactions by note, category, account, person or amount (like 120), '
                      'and accounts, people and budgets by name.',
                )
              : _Results(query: _query),
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final q = query.toLowerCase();
    bool has(String text) => text.toLowerCase().contains(q);

    final accounts = [
      for (final a in ref.watch(accountsProvider).value?.all ?? const <Account>[])
        if (has(a.name)) a,
    ];
    final people = [
      for (final p in ref.watch(peopleProvider).value?.people ?? const <Person>[])
        if (has(p.name)) p,
    ];
    final budgets = [
      for (final b in ref.watch(budgetsOverviewProvider(null)).value?.budgets ?? const <BudgetStatus>[])
        if (has(b.name) || b.categories.any((c) => has(c.name))) b,
    ];
    final txnFilter = txnQuery(q: query);
    final txns = ref.watch(filteredTxnsProvider(txnFilter));
    final found = txns.value?.items ?? const [];
    final nothing = accounts.isEmpty && people.isEmpty && budgets.isEmpty && txns.hasValue && found.isEmpty;

    if (nothing) {
      return EmptyState(
        icon: AppIcons.noResults,
        title: 'No results for “$query”',
        message: 'Try a different word, a category, an account, a person or an amount.',
      );
    }

    return LoadMoreListener(
      onLoadMore: () => unawaited(ref.read(filteredTxnsProvider(txnFilter).notifier).loadMore()),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (accounts.isNotEmpty) ...[
            const SectionLabel('Accounts'),
            for (final account in accounts)
              AccountTile(account: account, onTap: () => unawaited(context.push('/accounts/${account.id}'))),
          ],
          if (people.isNotEmpty) ...[
            const SectionLabel('People'),
            for (final person in people)
              PersonTile(person: person, onTap: () => unawaited(context.push('/people/${person.id}'))),
          ],
          if (budgets.isNotEmpty) ...[
            const SectionLabel('Budgets'),
            for (final budget in budgets)
              BudgetTile(budget: budget, onTap: () => unawaited(context.push('/budgets/${budget.id}'))),
          ],
          SectionLabel(
            txns.value == null ? 'Transactions' : 'Transactions · ${txns.value!.totals.count}',
          ),
          switch (txns) {
            AsyncValue(:final value?) when value.items.isEmpty => Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('No transactions match', style: TextStyle(color: colors.textSecondary)),
            ),
            AsyncValue(:final value?) => Column(
              children: [
                for (final txn in value.items)
                  TransactionTile(
                    txn: txn,
                    onTap: () => unawaited(showTxnForm(context, existing: txn)),
                  ),
                // More pages load as you scroll.
                if (value.hasMore) const LoadMoreFooter(),
              ],
            ),
            AsyncError(:final error) => Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      error is ApiException ? error.message : 'Couldn’t search transactions',
                      style: TextStyle(color: colors.danger),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(filteredTxnsProvider(txnFilter)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            _ => Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                ),
              ),
            ),
          },
        ],
      ),
    );
  }
}
