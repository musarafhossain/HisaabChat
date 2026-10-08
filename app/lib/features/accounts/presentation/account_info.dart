import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/animated_amount.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/presentation/account_form.dart';

/// Full-screen account info (phones; pushed from the accounts list).
class AccountInfoScreen extends ConsumerWidget {
  const AccountInfoScreen({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(),
      body: AccountInfoView(accountId: accountId, onDeleted: () => Navigator.of(context).maybePop()),
    );
  }
}

/// "Contact info" style page for an account (docs/04-UI-UX-Design-Brief.md §4.7).
/// Used full screen on phones and in the desktop detail pane.
class AccountInfoView extends ConsumerWidget {
  const AccountInfoView({required this.accountId, super.key, this.onDeleted});

  final String accountId;
  final VoidCallback? onDeleted;

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Account account) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${account.name}?'),
        content: const Text('This can’t be undone. Accounts with transactions can only be archived.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(context, () async {
      await ref.read(accountsProvider.notifier).delete(account.id);
      ref.read(selectedAccountProvider.notifier).select(null);
      onDeleted?.call();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountsProvider.select((s) => s.value?.byId(accountId)));
    if (account == null) {
      return const EmptyState(icon: AppIcons.accounts, title: 'Account not found');
    }

    final colors = context.colors;
    final theme = Theme.of(context);
    final controller = ref.read(accountsProvider.notifier);

    final stats = <(String, String)>[
      ('Opening balance', Money.format(account.openingBalance)),
      if (account.isCreditCard && account.creditLimit != null) ...[
        ('Credit limit', Money.format(account.creditLimit!)),
        ('Available', Money.format(account.availableCredit!)),
      ] else
        ('In total balance', account.includeInTotal ? 'Yes' : 'No'),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Center(
          child: Hero(
            tag: 'account-avatar-${account.id}',
            child: IconAvatar(icon: AppIcons.byKey(account.icon), color: account.color, radius: 48, solid: true),
          ),
        ),
        const SizedBox(height: 12),
        Text(account.name, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          account.type.label + (account.archived ? ' · Archived' : ''),
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text(
                account.isCreditCard ? 'Outstanding' : 'Balance',
                style: TextStyle(color: colors.textSecondary),
              ),
              AnimatedAmount(
                account.isCreditCard ? account.outstanding : account.balance,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: account.balance < 0 && !account.isCreditCard ? colors.expense : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (i, (label, value)) in stats.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: FadeSlideIn(
                    index: i,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                        child: Column(
                          children: [
                            Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SectionLabel('Transactions'),
        ListTile(
          leading: Icon(AppIcons.transactions, color: colors.textSecondary),
          title: const Text('Chat-style history'),
          subtitle: const Text('This account’s transactions appear here as a chat in Phase 3.'),
        ),
        const Divider(),
        SettingsTile(
          icon: AppIcons.edit,
          title: 'Edit account',
          onTap: () => showAccountForm(context, existing: account),
        ),
        SettingsTile(
          icon: AppIcons.archive,
          title: account.archived ? 'Unarchive account' : 'Archive account',
          subtitle: account.archived
              ? 'Show it in pickers and totals again'
              : 'Hide it from pickers and totals; history is kept',
          onTap: () => _run(context, () => controller.setArchived(account.id, archived: !account.archived)),
        ),
        SettingsTile(
          icon: AppIcons.delete,
          title: 'Delete account',
          destructive: true,
          onTap: () => _confirmDelete(context, ref, account),
        ),
      ],
    );
  }
}
