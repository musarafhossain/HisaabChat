import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/animated_amount.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/core/widgets/offline_banner.dart';
import 'package:hisaabchat/core/widgets/skeleton.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/accounts/presentation/account_form.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/budgets/data/budget.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_widgets.dart';
import 'package:hisaabchat/features/budgets/presentation/budgets_section.dart' show periodLabel;
import 'package:hisaabchat/features/reports/data/report.dart';
import 'package:hisaabchat/features/reports/reports_controller.dart';
import 'package:hisaabchat/features/shell/destinations.dart';
import 'package:hisaabchat/features/transactions/presentation/transactions_section.dart' show TransactionTile;
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';

/// Home dashboard (docs/04-UI-UX-Design-Brief.md §4.2): balance with this
/// month's money in/out, budget rings, and the latest transactions.
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
    final dashboard = ref.watch(dashboardProvider);
    final data = dashboard.value;
    final theme = Theme.of(context);
    final colors = context.colors;

    final header = FadeSlideIn(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${greeting(DateTime.now())}, ${user?.firstName ?? ''}',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (data != null)
              Text(periodLabel(data.periodStart, data.periodEnd), style: TextStyle(color: colors.textSecondary)),
          ],
        ),
      ),
    );

    final balance = FadeSlideIn(
      index: 1,
      child: _BalanceCard(dashboard: data, loading: dashboard.isLoading),
    );
    final budgets = FadeSlideIn(
      index: 2,
      child: _BudgetsRow(dashboard: data, loading: dashboard.isLoading),
    );
    final recent = FadeSlideIn(
      index: 3,
      child: _RecentList(dashboard: data, loading: dashboard.isLoading),
    );

    return Column(
      children: [
        if (dashboard.hasError && !dashboard.isLoading)
          OfflineBanner(error: dashboard.error!, onRetry: () => ref.invalidate(dashboardProvider)),
        Expanded(
          child: RefreshIndicator(
            color: colors.primary,
            onRefresh: () async {
              unawaited(ref.read(accountsProvider.notifier).refresh());
              try {
                final _ = await ref.refresh(dashboardProvider.future);
              } on Object {
                // The offline banner shows the error.
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Two columns on wide windows: money on the left, activity on the right.
                if (constraints.maxWidth >= 900) {
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              header,
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: Column(children: [balance, budgets])),
                                  Expanded(child: recent),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [header, balance, budgets, recent],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// "Budgets ·  See all" style header above a dashboard section.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('See all'),
            ),
        ],
      ),
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.dashboard, required this.loading});

  final Dashboard? dashboard;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value;
    final dashboard = this.dashboard;

    if (accounts != null && accounts.active.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
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
      );
    }

    // Accounts refresh live after every change; the dashboard is the fallback.
    final total = accounts?.netWorth ?? dashboard?.netWorth;
    final count = accounts?.active.length ?? dashboard?.accountsCount ?? 0;

    Widget stat(String label, IconData icon, Color color, int? paise) => Expanded(
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                if (paise == null && loading)
                  const Padding(padding: EdgeInsets.only(top: 4), child: Skeleton(width: 72))
                else if (paise == null)
                  Text('—', style: TextStyle(fontSize: 16, color: colors.textSecondary))
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedAmount(
                      paise,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(Destination.accounts.path),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total balance', style: TextStyle(color: colors.textSecondary)),
                          if (total == null && loading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Skeleton(width: 160, height: 26),
                            )
                          else if (total == null)
                            Text('—', style: theme.textTheme.headlineMedium)
                          else
                            AnimatedAmount(
                              total,
                              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          Text(
                            'Across $count ${count == 1 ? 'account' : 'accounts'}',
                            style: TextStyle(fontSize: 13, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(AppIcons.chevron, color: colors.textSecondary),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: colors.divider),
                ),
                Row(
                  children: [
                    stat('Money in', AppIcons.income, colors.income, dashboard?.income),
                    stat('Money out', AppIcons.expense, colors.expense, dashboard?.expense),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// WhatsApp "status" style row of budget rings.
class _BudgetsRow extends StatelessWidget {
  const _BudgetsRow({required this.dashboard, required this.loading});

  final Dashboard? dashboard;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final budgets = dashboard?.budgets;
    final seeAll = budgets == null || budgets.isEmpty ? null : () => context.go(Destination.budgets.path);

    Widget body;
    if (budgets == null) {
      body = loading
          ? SizedBox(
              height: 104,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < 4; i++)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Column(
                        children: [Skeleton.circle(size: 64), SizedBox(height: 10), Skeleton(width: 56, height: 10)],
                      ),
                    ),
                ],
              ),
            )
          : const SizedBox.shrink();
    } else if (budgets.isEmpty) {
      body = ChatTile(
        leading: IconAvatar(icon: AppIcons.addBudget, color: colors.primary),
        title: 'Set up a budget',
        subtitle: 'Rent, food, bike EMI + petrol, education…',
        trailing: Icon(AppIcons.chevron, color: colors.textSecondary),
        onTap: () => context.go(Destination.budgets.path),
      );
    } else {
      body = SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: budgets.length,
          itemBuilder: (context, i) => _BudgetBubble(budget: budgets[i]),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader('Budgets this month', onSeeAll: seeAll),
        AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: body),
      ],
    );
  }
}

class _BudgetBubble extends StatelessWidget {
  const _BudgetBubble({required this.budget});

  final BudgetStatus budget;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: '${budget.name}, ${budget.percent} percent used',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => unawaited(context.push('/budgets/${budget.id}')),
        child: SizedBox(
          width: 84,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                BudgetRingAvatar(budget: budget, size: 64),
                const SizedBox(height: 6),
                Text(
                  budget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5),
                ),
                Text(
                  '${budget.percent}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: budgetStateColor(colors, budget.state),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.dashboard, required this.loading});

  final Dashboard? dashboard;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final recent = dashboard?.recent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          'Recent',
          onSeeAll: recent == null || recent.isEmpty ? null : () => context.go(Destination.transactions.path),
        ),
        if (recent == null && loading)
          for (var i = 0; i < 4; i++) const SkeletonTile()
        else if (recent != null && recent.isEmpty)
          ChatTile(
            leading: IconAvatar(icon: AppIcons.send, color: colors.primary),
            title: 'No transactions yet',
            subtitle: 'Open an account and type “120 petrol”, or tap +',
          )
        else if (recent != null)
          for (final txn in recent)
            TransactionTile(
              txn: txn,
              onTap: () => unawaited(showTxnForm(context, existing: txn)),
            ),
      ],
    );
  }
}
