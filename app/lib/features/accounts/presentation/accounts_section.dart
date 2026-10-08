import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/animated_amount.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/list_detail_layout.dart';
import 'package:hisaabchat/core/widgets/search_pill.dart';
import 'package:hisaabchat/core/widgets/window_class.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/presentation/account_form.dart';
import 'package:hisaabchat/features/accounts/presentation/account_info.dart';
import 'package:hisaabchat/features/accounts/presentation/account_tile.dart';
import 'package:hisaabchat/features/transactions/presentation/account_thread.dart';

/// Accounts tab: the "chats" list. On desktop the selected account's thread
/// opens in the detail pane (WhatsApp Desktop); on phones it opens full screen.
class AccountsSection extends ConsumerStatefulWidget {
  const AccountsSection({super.key});

  @override
  ConsumerState<AccountsSection> createState() => _AccountsSectionState();
}

class _AccountsSectionState extends ConsumerState<AccountsSection> {
  /// Desktop: show "Account info" instead of the thread for this account.
  String? _infoFor;

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedAccountProvider);
    final colors = context.colors;

    Widget detail;
    if (selectedId == null) {
      detail = const EmptyDetailPane(icon: AppIcons.accounts, message: 'Select an account to see its transactions');
    } else if (_infoFor == selectedId) {
      detail = Material(
        key: ValueKey('info-$selectedId'),
        child: Column(
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: colors.panel,
                border: Border(bottom: BorderSide(color: colors.divider)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to chat',
                    icon: const Icon(AppIcons.back),
                    onPressed: () => setState(() => _infoFor = null),
                  ),
                  const Text('Account info', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Expanded(child: AccountInfoView(accountId: selectedId)),
          ],
        ),
      );
    } else {
      detail = AccountThread(
        key: ValueKey('thread-$selectedId'),
        accountId: selectedId,
        fullScreen: false,
        onOpenInfo: () => setState(() => _infoFor = selectedId),
      );
    }
    return ListDetailLayout(list: const _AccountsList(), detail: detail);
  }
}

class _AccountsList extends ConsumerStatefulWidget {
  const _AccountsList();

  @override
  ConsumerState<_AccountsList> createState() => _AccountsListState();
}

class _AccountsListState extends ConsumerState<_AccountsList> {
  String _query = '';
  AccountType? _type;
  bool _showArchived = false;

  void _open(Account account) {
    if (context.windowClass == WindowClass.expanded) {
      ref.read(selectedAccountProvider.notifier).select(account.id);
    } else {
      context.go('/accounts/${account.id}');
    }
  }

  bool _matches(Account account) =>
      (_type == null || account.type == _type) &&
      (_query.isEmpty || account.name.toLowerCase().contains(_query.toLowerCase()));

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final selectedId = ref.watch(selectedAccountProvider);
    final colors = context.colors;

    return switch (accounts) {
      AsyncValue(:final value?) when value.all.isEmpty => EmptyState(
        icon: AppIcons.accounts,
        title: 'No accounts yet',
        message: 'Add your cash, bank accounts and UPI wallets. Each one becomes a chat for its transactions.',
        action: FilledButton.icon(
          onPressed: () => showAccountForm(context),
          icon: const Icon(AppIcons.addAccount),
          label: const Text('Add account'),
        ),
      ),
      AsyncValue(:final value?) => _buildList(context, value, selectedId),
      AsyncError(:final error) => EmptyState(
        icon: AppIcons.offline,
        title: 'Couldn’t load accounts',
        message: error is ApiException ? error.message : '$error',
        action: FilledButton.icon(
          onPressed: () => ref.read(accountsProvider.notifier).refresh(),
          icon: const Icon(AppIcons.refresh),
          label: const Text('Try again'),
        ),
      ),
      _ => Center(child: CircularProgressIndicator(color: colors.primary)),
    };
  }

  Widget _buildList(BuildContext context, AccountsState state, String? selectedId) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final types = AccountType.values.where((t) => state.active.any((a) => a.type == t)).toList();
    final active = state.active.where(_matches).toList();
    final archived = state.archived.where(_matches).toList();

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => ref.read(accountsProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total balance', style: TextStyle(color: colors.textSecondary)),
                    AnimatedAmount(
                      state.netWorth,
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${state.active.length} ${state.active.length == 1 ? 'account' : 'accounts'}',
                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SearchPill(hint: 'Search accounts', onChanged: (value) => setState(() => _query = value.trim())),
          if (types.length > 1)
            FilterChipsRow(
              labels: ['All', ...types.map((t) => t.shortLabel)],
              selected: _type == null ? 0 : types.indexOf(_type!) + 1,
              onSelected: (i) => setState(() => _type = i == 0 ? null : types[i - 1]),
            ),
          if (active.isEmpty && state.active.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No accounts match',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          for (final (i, account) in active.indexed)
            FadeSlideIn(
              key: ValueKey(account.id),
              index: i,
              child: AccountTile(
                account: account,
                selected: account.id == selectedId && context.windowClass == WindowClass.expanded,
                onTap: () => _open(account),
              ),
            ),
          if (state.archived.isNotEmpty) ...[
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(AppIcons.archive, color: colors.textSecondary),
              title: Text('Archived (${state.archived.length})'),
              trailing: AnimatedRotation(
                turns: _showArchived ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(AppIcons.chevron, color: colors.textSecondary),
              ),
              onTap: () => setState(() => _showArchived = !_showArchived),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _showArchived
                  ? Column(
                      children: [
                        for (final account in archived)
                          AccountTile(
                            account: account,
                            selected: account.id == selectedId && context.windowClass == WindowClass.expanded,
                            onTap: () => _open(account),
                          ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}
