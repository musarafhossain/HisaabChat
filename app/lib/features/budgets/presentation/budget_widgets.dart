import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/ring_progress.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/features/budgets/data/budget.dart';

/// Status color: green on track, amber past the alert level, red over.
Color budgetStateColor(AppColors colors, BudgetState state) => switch (state) {
  BudgetState.ok => colors.primary,
  BudgetState.warning => colors.warning,
  BudgetState.exceeded => colors.danger,
};

/// "₹3,400 of ₹4,000 · ₹50/day left", "Over by ₹350", "₹600 left".
String budgetSummary(BudgetStatus budget) {
  final base = '${Money.format(budget.spent)} of ${Money.format(budget.available)}';
  if (budget.remaining < 0) return '$base · Over by ${Money.format(-budget.remaining)}';
  final perDay = budget.safeToSpendPerDay;
  if (perDay != null && budget.daysLeft > 0) return '$base · ${Money.format(wholeRupees(perDay))}/day left';
  return '$base · ${Money.format(budget.remaining)} left';
}

/// Rounds paise down to whole rupees (per-day guidance doesn't need paise).
int wholeRupees(int paise) => paise ~/ 100 * 100;

/// The budget's icon inside its progress ring (WhatsApp "status ring").
class BudgetRingAvatar extends StatelessWidget {
  const BudgetRingAvatar({required this.budget, super.key, this.size = 56});

  final BudgetStatus budget;
  final double size;

  @override
  Widget build(BuildContext context) {
    return RingProgress(
      progress: budget.progress,
      alertAt: budget.alertPercent / 100,
      size: size,
      strokeWidth: size > 80 ? 6 : 3,
      semanticsLabel: '${budget.name} budget',
      child: IconAvatar(
        icon: AppIcons.byKey(budget.icon),
        color: budget.color,
        radius: size / 2 - (size > 80 ? 12 : 7),
      ),
    );
  }
}

/// Small rounded percentage pill in the status color.
class PercentPill extends StatelessWidget {
  const PercentPill({required this.percent, required this.state, super.key});

  final int percent;
  final BudgetState state;

  @override
  Widget build(BuildContext context) {
    final color = budgetStateColor(context.colors, state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state != BudgetState.ok) ...[
            Icon(state == BudgetState.exceeded ? AppIcons.over : AppIcons.warning, size: 13, color: color, fill: 1),
            const SizedBox(width: 3),
          ],
          Text(
            '$percent%',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chat-list row for a budget.
class BudgetTile extends StatelessWidget {
  const BudgetTile({required this.budget, super.key, this.selected = false, this.onTap});

  final BudgetStatus budget;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ChatTile(
      selected: selected,
      onTap: onTap,
      leading: BudgetRingAvatar(budget: budget),
      title: budget.name,
      subtitle: budgetSummary(budget),
      trailing: PercentPill(percent: budget.percent, state: budget.state),
      trailingCaption: budget.hasOverride ? 'This month only' : budget.kind.label,
    );
  }
}
