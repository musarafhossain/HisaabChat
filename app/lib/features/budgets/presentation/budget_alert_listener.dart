import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/budgets/budgets_controller.dart';

/// Turns budget alerts from saved expenses into toasts, wherever the expense
/// was added (composer, full form). Sits just below the ToastHost.
class BudgetAlertListener extends ConsumerWidget {
  const BudgetAlertListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(budgetAlertsProvider, (_, alert) {
      if (alert == null) return;
      AppToast.show(
        context,
        alert.exceeded
            ? '${alert.name} is over by ${Money.format(-alert.remaining)}'
            : '${alert.name} · ${alert.percent}% used',
        kind: alert.exceeded ? ToastKind.error : ToastKind.warning,
      );
    });
    return child;
  }
}
