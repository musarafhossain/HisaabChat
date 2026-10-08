import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/animated_amount.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/accounts/presentation/account_form.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/shell/destinations.dart';

/// Home. The full dashboard (budget rings, upcoming, recent) is built in
/// Phase 5; for now it shows the total balance and the roadmap.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final colors = context.colors;
    final theme = Theme.of(context);

    const roadmap = [
      (AppIcons.accounts, 'Accounts', 'Cash, bank and UPI, each one a chat', 'Ready'),
      (AppIcons.send, 'Quick add', 'Type “120 petrol” and send', 'Phase 3'),
      (AppIcons.budgets, 'Budgets', 'Rings for Rent, Food, Bike EMI + Petrol…', 'Phase 4'),
      (AppIcons.home, 'Dashboard & reports', 'Your month at a glance', 'Phase 5'),
      (AppIcons.people, 'Lend & borrow', 'Who owes whom, per person', 'Phase 6'),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            FadeSlideIn(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${greeting(DateTime.now())}, ${user?.firstName ?? ''}',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const FadeSlideIn(index: 1, child: _BalanceCard()),
            const FadeSlideIn(index: 2, child: SectionLabel('What’s ready and what’s next')),
            for (final (i, (icon, title, subtitle, status)) in roadmap.indexed)
              FadeSlideIn(
                index: 3 + i,
                child: ChatTile(
                  leading: IconAvatar(icon: icon, color: colors.primary),
                  title: title,
                  subtitle: subtitle,
                  trailing: status == 'Ready' ? Icon(AppIcons.ok, color: colors.primary, fill: 1, size: 20) : null,
                  trailingCaption: status,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value;
    final hasAccounts = accounts != null && accounts.active.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: hasAccounts ? () => context.go(Destination.accounts.path) : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: hasAccounts
                ? Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total balance', style: TextStyle(color: colors.textSecondary)),
                            AnimatedAmount(
                              accounts.netWorth,
                              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Across ${accounts.active.length} '
                              '${accounts.active.length == 1 ? 'account' : 'accounts'}',
                              style: TextStyle(fontSize: 13, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(AppIcons.chevron, color: colors.textSecondary),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add your first account', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Start with your cash, then add bank accounts and UPI wallets.',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => showAccountForm(context),
                        icon: const Icon(AppIcons.addAccount),
                        label: const Text('Add account'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
