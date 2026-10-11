import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/format/dates.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/load_more.dart';
import 'package:hisaabchat/core/widgets/offline_banner.dart';
import 'package:hisaabchat/core/widgets/skeleton.dart';
import 'package:hisaabchat/features/transactions/data/transactions_repository.dart';
import 'package:hisaabchat/features/transactions/presentation/transactions_section.dart' show TransactionTile;
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';
import 'package:hisaabchat/features/transactions/transactions_controller.dart';

/// The transactions behind one Reports row: a category within a period,
/// paged as you scroll. The count and total cover all of them.
class CategoryTransactionsScreen extends ConsumerWidget {
  const CategoryTransactionsScreen({
    required this.categoryId,
    required this.name,
    required this.from,
    required this.to,
    required this.period,
    super.key,
  });

  final String categoryId;
  final String name;
  final DateTime from;
  final DateTime to;

  /// "October 2026"
  final String period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = txnQuery(categoryId: categoryId, from: from, to: to);
    final state = ref.watch(filteredTxnsProvider(query));
    final colors = context.colors;
    final value = state.value;

    Widget body;
    if (value == null) {
      body = state.hasError
          ? EmptyState(
              icon: AppIcons.offline,
              title: 'Couldn’t load transactions',
              message: OfflineBanner.messageFor(state.error!),
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(filteredTxnsProvider(query)),
                icon: const Icon(AppIcons.refresh),
                label: const Text('Try again'),
              ),
            )
          : ListView(children: [for (var i = 0; i < 5; i++) const SkeletonTile()]);
    } else if (value.items.isEmpty) {
      body = const EmptyState(
        icon: AppIcons.transactions,
        title: 'Nothing here now',
        message: 'These were changed or removed.',
      );
    } else {
      final items = value.items;
      // From the server: every matching transaction, not just the loaded pages.
      final count = value.totals.count;
      final total = value.totals.income + value.totals.expense;
      body = LoadMoreListener(
        onLoadMore: () => unawaited(ref.read(filteredTxnsProvider(query).notifier).loadMore()),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: items.length + 1 + (value.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  '$count ${count == 1 ? 'transaction' : 'transactions'} · ${Money.format(total)}',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.textSecondary),
                ),
              );
            }
            if (index > items.length) return const LoadMoreFooter();
            final txn = items[index - 1];
            final showDay = index == 1 || !Dates.sameDay(items[index - 2].localDate, txn.localDate);
            return FadeSlideIn(
              index: index < 10 ? index : 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDay)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                      child: Text(
                        Dates.dayChip(txn.localDate),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textSecondary),
                      ),
                    ),
                  TransactionTile(
                    txn: txn,
                    onTap: () => unawaited(showTxnForm(context, existing: txn)),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(period, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: body),
      ),
    );
  }
}
