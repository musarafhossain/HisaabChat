import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/format/dates.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/list_detail_layout.dart';
import 'package:hisaabchat/core/widgets/search_pill.dart';
import 'package:hisaabchat/core/widgets/window_class.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';
import 'package:hisaabchat/features/transactions/transactions_controller.dart';

/// Chat-list row for a transaction (Transactions tab).
class TransactionTile extends StatelessWidget {
  const TransactionTile({required this.txn, super.key, this.selected = false, this.onTap});

  final Txn txn;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (IconData icon, Color color) = switch (txn.type) {
      TxnType.transfer => (AppIcons.transfer, colors.transfer),
      TxnType.adjustment => (AppIcons.adjustment, colors.textSecondary),
      _ => (AppIcons.byKey(txn.category?.icon ?? 'category'), txn.category?.color ?? colors.textSecondary),
    };
    final (String amount, Color amountColor) = switch (txn.type) {
      TxnType.income => (Money.format(txn.amount, signed: true), colors.income),
      TxnType.expense => (Money.format(-txn.amount), colors.expense),
      TxnType.transfer => (Money.format(txn.amount), colors.transfer),
      TxnType.adjustment => (
        Money.format(txn.adjustmentIncrease ?? false ? txn.amount : -txn.amount, signed: true),
        colors.textSecondary,
      ),
    };
    final subtitle = [
      if (txn.type == TxnType.transfer) 'From ${txn.account.name}' else txn.account.name,
      if (txn.note != null && txn.note!.isNotEmpty && txn.note != txn.labelFor(null)) txn.note!,
    ].join(' · ');

    return ChatTile(
      selected: selected,
      onTap: onTap,
      leading: IconAvatar(icon: icon, color: color),
      title: txn.labelFor(null),
      subtitle: subtitle,
      trailing: Text(
        amount,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: amountColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      trailingCaption: Dates.time(txn.localDate),
    );
  }
}

/// Transactions tab: search, type chips, totals, day groups, infinite scroll.
class TransactionsSection extends ConsumerStatefulWidget {
  const TransactionsSection({super.key});

  @override
  ConsumerState<TransactionsSection> createState() => _TransactionsSectionState();
}

class _TransactionsSectionState extends ConsumerState<TransactionsSection> {
  static const List<TxnType?> _types = [null, TxnType.expense, TxnType.income, TxnType.transfer];
  final _scroll = ScrollController();
  Timer? _debounce;
  String _query = '';
  int _typeIndex = 0;
  Txn? _selected;

  TxnFilter get _filter => (type: _types[_typeIndex], q: _query);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) {
        unawaited(ref.read(transactionsListProvider(_filter).notifier).loadMore());
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _query = value.trim()));
  }

  void _open(Txn txn) {
    if (context.windowClass == WindowClass.expanded) {
      setState(() => _selected = txn);
    } else {
      unawaited(showTxnForm(context, existing: txn));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return ListDetailLayout(
      list: _list(context),
      detail: selected == null
          ? const EmptyDetailPane(icon: AppIcons.transactions, message: 'Select a transaction to edit it')
          : Material(
              key: ValueKey(selected.id),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Edit transaction', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
                    trailing: IconButton(
                      tooltip: 'Close',
                      icon: const Icon(AppIcons.close),
                      onPressed: () => setState(() => _selected = null),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: TxnForm(existing: selected, onDone: (_) => setState(() => _selected = null)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _list(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(transactionsListProvider(_filter));

    final header = <Widget>[
      const SizedBox(height: 4),
      SearchPill(hint: 'Search notes and categories', onChanged: _search),
      FilterChipsRow(
        labels: const ['All', 'Expense', 'Income', 'Transfer'],
        selected: _typeIndex,
        onSelected: (i) => setState(() => _typeIndex = i),
      ),
    ];

    final value = state.value;
    if (value == null) {
      return Column(
        children: [
          ...header,
          Expanded(
            child: state.hasError
                ? EmptyState(
                    icon: AppIcons.offline,
                    title: 'Couldn’t load transactions',
                    message: state.error is ApiException ? (state.error! as ApiException).message : '${state.error}',
                    action: FilledButton.icon(
                      onPressed: () => ref.invalidate(transactionsListProvider(_filter)),
                      icon: const Icon(AppIcons.refresh),
                      label: const Text('Try again'),
                    ),
                  )
                : Center(child: CircularProgressIndicator(color: colors.primary)),
          ),
        ],
      );
    }

    if (value.items.isEmpty) {
      final filtered = _query.isNotEmpty || _typeIndex != 0;
      return Column(
        children: [
          ...header,
          Expanded(
            child: EmptyState(
              icon: filtered ? AppIcons.noResults : AppIcons.transactions,
              title: filtered ? 'Nothing matches' : 'No transactions yet',
              message: filtered
                  ? 'Try another word or filter.'
                  : 'Open an account and type an amount, like “120 petrol”, or tap +.',
            ),
          ),
        ],
      );
    }

    // Flatten into day headers + rows.
    final rows = <Object>[];
    for (var i = 0; i < value.items.length; i++) {
      final txn = value.items[i];
      if (i == 0 || !Dates.sameDay(value.items[i - 1].localDate, txn.localDate)) {
        final dayItems = value.items.where((t) => Dates.sameDay(t.localDate, txn.localDate));
        final net = dayItems.fold<int>(
          0,
          (sum, t) =>
              sum +
              switch (t.type) {
                TxnType.income => t.amount,
                TxnType.expense => -t.amount,
                _ => 0,
              },
        );
        rows.add((Dates.dayChip(txn.localDate), net));
      }
      rows.add(txn);
    }

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => ref.refresh(transactionsListProvider(_filter).future),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: header.length + 1 + rows.length + (value.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < header.length) return header[index];
          if (index == header.length) return _totals(context, value.totals);
          final i = index - header.length - 1;
          if (i >= rows.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          final row = rows[i];
          if (row is (String, int)) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                '${row.$1} · ${Money.format(row.$2, signed: true)}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textSecondary),
              ),
            );
          }
          final txn = row as Txn;
          return FadeSlideIn(
            key: ValueKey(txn.id),
            index: i < 10 ? i : 0,
            child: TransactionTile(
              txn: txn,
              selected: _selected?.id == txn.id && context.windowClass == WindowClass.expanded,
              onTap: () => _open(txn),
            ),
          );
        },
      ),
    );
  }

  Widget _totals(BuildContext context, TxnTotals totals) {
    final colors = context.colors;
    Widget stat(String label, int paise, Color color) => Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
          Text(
            Money.format(paise, signed: true),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              stat('Money in', totals.income, colors.income),
              stat('Money out', -totals.expense, colors.expense),
              stat('Net', totals.income - totals.expense, colors.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
