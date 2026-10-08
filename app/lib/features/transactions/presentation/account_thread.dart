import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/format/dates.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/motion/motion.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/presentation/account_form.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:hisaabchat/features/transactions/presentation/doodle_wallpaper.dart';
import 'package:hisaabchat/features/transactions/presentation/quick_composer.dart';
import 'package:hisaabchat/features/transactions/presentation/reconcile_dialog.dart';
import 'package:hisaabchat/features/transactions/presentation/thread_widgets.dart';
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';
import 'package:hisaabchat/features/transactions/transactions_controller.dart';

/// An account as a WhatsApp chat (docs/04-UI-UX-Design-Brief.md §4.4).
///
/// [fullScreen] (phones) wraps it in a Scaffold with an app bar; otherwise it
/// fills the desktop detail pane with its own header row.
class AccountThread extends ConsumerStatefulWidget {
  const AccountThread({required this.accountId, required this.onOpenInfo, super.key, this.fullScreen = true});

  final String accountId;
  final VoidCallback onOpenInfo;
  final bool fullScreen;

  @override
  ConsumerState<AccountThread> createState() => _AccountThreadState();
}

/// One row in the reversed list.
sealed class _Entry {}

class _TxnEntry extends _Entry {
  _TxnEntry(this.txn, {this.status});
  final Txn txn;
  final PendingStatus? status;
}

class _DayEntry extends _Entry {
  _DayEntry(this.label);
  final String label;
}

class _SystemEntry extends _Entry {
  _SystemEntry(this.text);
  final String text;
}

class _AccountThreadState extends ConsumerState<AccountThread> {
  final _scroll = ScrollController();
  final Set<String> _selected = {};
  final Map<String, int> _shakes = {};
  bool _showJump = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scroll.offset > 400;
    if (show != _showJump) setState(() => _showJump = show);
    if (_scroll.position.extentAfter < 400) {
      unawaited(ref.read(accountThreadProvider(widget.accountId).notifier).loadMore());
    }
  }

  List<_Entry> _entries(Account account, TxnListState? state, List<PendingTxn> pending) {
    final confirmed = state?.items ?? const <Txn>[];
    final confirmedIds = {for (final t in confirmed) t.id};
    final mine = pending
        .where((p) => !confirmedIds.contains(p.id) && p.body['accountId'] == account.id)
        .toList()
        .reversed;

    final rows = <_TxnEntry>[
      for (final p in mine) _TxnEntry(p.preview, status: p.status),
      for (final t in confirmed) _TxnEntry(t),
    ];

    // Newest first; a day chip goes after (= above, in a reversed list) each day's group.
    final entries = <_Entry>[];
    for (var i = 0; i < rows.length; i++) {
      entries.add(rows[i]);
      final day = rows[i].txn.localDate;
      final next = i + 1 < rows.length ? rows[i + 1].txn.localDate : null;
      if (next == null || !Dates.sameDay(day, next)) {
        final net = rows
            .where((r) => Dates.sameDay(r.txn.localDate, day))
            .fold<int>(0, (sum, r) => sum + r.txn.signedFor(account.id));
        entries.add(_DayEntry('${Dates.dayChip(day)} · ${Money.format(net, signed: true)}'));
      }
    }
    if (state != null && !state.hasMore) {
      entries.add(
        _SystemEntry(
          account.isCreditCard
              ? 'Card added with ${Money.format(-account.openingBalance)} outstanding'
              : 'Account opened with ${Money.format(account.openingBalance)}',
        ),
      );
    }
    return entries;
  }

  Future<void> _deleteSelected(List<Txn> txns) async {
    final mutations = ref.read(txnMutationsProvider);
    try {
      for (final txn in txns) {
        await mutations.delete(txn.id);
      }
      if (!mounted) return;
      setState(_selected.clear);
      showDeletedToast(context, ref, txns);
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    }
  }

  Future<void> _duplicateSelected(List<Txn> txns) async {
    final mutations = ref.read(txnMutationsProvider);
    try {
      for (final txn in txns.reversed) {
        final body = txn.toCreateBody()
          ..remove('id')
          ..['date'] = DateTime.now().toUtc().toIso8601String();
        await mutations.create(body);
      }
      if (!mounted) return;
      setState(_selected.clear);
      AppToast.success(context, txns.length == 1 ? 'Duplicated' : 'Duplicated ${txns.length} transactions');
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    }
  }

  void _onBubbleTap(_TxnEntry entry) {
    if (_selected.isNotEmpty) return _toggleSelected(entry);
    if (entry.status == PendingStatus.failed) {
      setState(() => _shakes[entry.txn.id] = (_shakes[entry.txn.id] ?? 0) + 1);
      final pending = ref.read(pendingTxnsProvider).firstWhere((p) => p.id == entry.txn.id);
      unawaited(ref.read(txnMutationsProvider).send(pending));
      return;
    }
    if (entry.status == null) unawaited(showTxnForm(context, existing: entry.txn));
  }

  void _toggleSelected(_TxnEntry entry) {
    if (entry.status != null) return; // only saved transactions
    setState(() => _selected.contains(entry.txn.id) ? _selected.remove(entry.txn.id) : _selected.add(entry.txn.id));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final account = ref.watch(accountsProvider.select((s) => s.value?.byId(widget.accountId)));
    if (account == null) {
      const body = EmptyState(icon: AppIcons.accounts, title: 'Account not found');
      return widget.fullScreen ? Scaffold(appBar: AppBar(), body: body) : body;
    }

    final thread = ref.watch(accountThreadProvider(widget.accountId));
    final pending = ref.watch(pendingTxnsProvider);
    final entries = _entries(account, thread.value, pending);
    final selectedTxns = [
      for (final e in entries)
        if (e is _TxnEntry && _selected.contains(e.txn.id)) e.txn,
    ];
    final recentCategoryIds = [
      for (final e in entries)
        if (e is _TxnEntry && e.txn.category != null) e.txn.category!.id,
    ];

    final list = switch (thread) {
      AsyncError(:final error) when thread.value == null => EmptyState(
        icon: AppIcons.offline,
        title: 'Couldn’t load transactions',
        message: error is ApiException ? error.message : '$error',
        action: FilledButton.icon(
          onPressed: () => ref.invalidate(accountThreadProvider(widget.accountId)),
          icon: const Icon(AppIcons.refresh),
          label: const Text('Try again'),
        ),
      ),
      _ when thread.value == null => Center(child: CircularProgressIndicator(color: colors.primary)),
      _ => ListView.builder(
        controller: _scroll,
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: entries.length + ((thread.value?.loadingMore ?? false) ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= entries.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          return switch (entries[index]) {
            _TxnEntry(:final txn, :final status) => TxnBubble(
              key: ValueKey(txn.id),
              txn: txn,
              accountId: account.id,
              status: status,
              selected: _selected.contains(txn.id),
              shakeTrigger: _shakes[txn.id] ?? 0,
              onTap: () => _onBubbleTap(entries[index] as _TxnEntry),
              onLongPress: () => _toggleSelected(entries[index] as _TxnEntry),
            ),
            _DayEntry(:final label) => ThreadChip(text: label),
            _SystemEntry(:final text) => ThreadChip(text: text, icon: AppIcons.info),
          };
        },
      ),
    };

    final body = Column(
      children: [
        if (!widget.fullScreen) _header(context, account, selectedTxns),
        Expanded(
          child: DoodleWallpaper(
            child: Stack(
              children: [
                Positioned.fill(
                  child: entries.isEmpty && thread.hasValue
                      ? Center(
                          child: ThreadChip(
                            text: 'No transactions in ${account.name} yet. Type an amount below to add one.',
                            icon: AppIcons.info,
                          ),
                        )
                      : list,
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: AnimatedScale(
                    scale: _showJump ? 1 : 0,
                    duration: context.motion(Motion.medium),
                    curve: _showJump ? Motion.pop : Motion.exit,
                    child: FloatingActionButton.small(
                      heroTag: null,
                      tooltip: 'Jump to latest',
                      backgroundColor: colors.panel,
                      foregroundColor: colors.textSecondary,
                      onPressed: () => _scroll.animateTo(
                        0,
                        duration: context.motion(const Duration(milliseconds: 400)),
                        curve: Motion.settle,
                      ),
                      child: const Icon(AppIcons.jumpToLatest),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (account.archived)
          Container(
            width: double.infinity,
            color: colors.panel,
            padding: const EdgeInsets.all(16),
            child: Text(
              '${account.name} is archived. Unarchive it from Account info to add transactions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
          )
        else
          QuickComposer(account: account, recentCategoryIds: recentCategoryIds),
      ],
    );

    if (!widget.fullScreen) return body;
    return Scaffold(
      appBar: _selected.isNotEmpty ? _selectionBar(selectedTxns) : _appBar(context, account),
      body: body,
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, Account account) {
    return AppBar(
      titleSpacing: 0,
      title: InkWell(
        onTap: widget.onOpenInfo,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _titleRow(context, account),
        ),
      ),
      actions: [_menu(context, account)],
    );
  }

  PreferredSizeWidget _selectionBar(List<Txn> selected) {
    return AppBar(
      leading: IconButton(
        tooltip: 'Cancel selection',
        icon: const Icon(AppIcons.close),
        onPressed: () => setState(_selected.clear),
      ),
      title: FadeSlideIn(
        key: ValueKey(_selected.length),
        offset: 6,
        child: Text('${_selected.length}', style: const TextStyle(fontSize: 20)),
      ),
      actions: _selectionActions(selected),
    );
  }

  List<Widget> _selectionActions(List<Txn> selected) => [
    IconButton(
      tooltip: 'Duplicate',
      icon: const Icon(AppIcons.duplicate),
      onPressed: () => _duplicateSelected(selected),
    ),
    IconButton(tooltip: 'Delete', icon: const Icon(AppIcons.delete), onPressed: () => _deleteSelected(selected)),
  ];

  Widget _titleRow(BuildContext context, Account account) {
    final colors = context.colors;
    return Row(
      children: [
        Hero(
          tag: 'account-avatar-${account.id}',
          child: IconAvatar(icon: AppIcons.byKey(account.icon), color: account.color, radius: 20, solid: true),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                account.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              Text(
                account.isCreditCard
                    ? 'Outstanding ${Money.format(account.outstanding)}'
                    : 'Balance ${Money.format(account.balance)}',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menu(BuildContext context, Account account) {
    return PopupMenuButton<String>(
      tooltip: 'More options',
      icon: const Icon(AppIcons.more),
      onSelected: (value) => switch (value) {
        'info' => widget.onOpenInfo(),
        'reconcile' => showReconcileDialog(context, account),
        'edit' => showAccountForm(context, existing: account),
        _ => null,
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'info', child: Text('Account info')),
        PopupMenuItem(value: 'reconcile', child: Text('Reconcile balance')),
        PopupMenuItem(value: 'edit', child: Text('Edit account')),
      ],
    );
  }

  /// Desktop pane header (the detail pane has no AppBar).
  Widget _header(BuildContext context, Account account, List<Txn> selected) {
    final colors = context.colors;
    return Material(
      color: colors.panel,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: AnimatedSwitcher(
          duration: context.motion(Motion.medium),
          child: _selected.isNotEmpty
              ? Row(
                  key: const ValueKey('selection'),
                  children: [
                    IconButton(
                      tooltip: 'Cancel selection',
                      icon: const Icon(AppIcons.close),
                      onPressed: () => setState(_selected.clear),
                    ),
                    Text('${_selected.length} selected', style: const TextStyle(fontSize: 17)),
                    const Spacer(),
                    ..._selectionActions(selected),
                  ],
                )
              : Row(
                  key: const ValueKey('header'),
                  children: [
                    Expanded(
                      child: InkWell(onTap: widget.onOpenInfo, child: _titleRow(context, account)),
                    ),
                    _menu(context, account),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Full-screen thread route (phones): `/accounts/:id`.
class AccountThreadScreen extends StatelessWidget {
  const AccountThreadScreen({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    return AccountThread(accountId: accountId, onOpenInfo: () => context.push('/accounts/$accountId/info'));
  }
}
