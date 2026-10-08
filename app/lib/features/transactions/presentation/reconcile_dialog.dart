import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/amount_field.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/transactions/transactions_controller.dart';

/// "What's the actual balance?" → records the difference as an adjustment.
Future<void> showReconcileDialog(BuildContext context, Account account) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showDialog<String>(
    context: context,
    builder: (context) => _ReconcileDialog(account: account),
  );
  if (message != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReconcileDialog extends ConsumerStatefulWidget {
  const _ReconcileDialog({required this.account});

  final Account account;

  @override
  ConsumerState<_ReconcileDialog> createState() => _ReconcileDialogState();
}

class _ReconcileDialogState extends ConsumerState<_ReconcileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final entered = AmountField.paiseOf(_amount) ?? 0;
    // Cards: the user enters what they owe; the balance is its negative.
    final actual = widget.account.isCreditCard ? -entered : entered;

    setState(() => _saving = true);
    try {
      final adjustment = await ref.read(txnMutationsProvider).reconcile(widget.account.id, actual);
      if (!mounted) return;
      Navigator.of(context).pop(
        adjustment == null
            ? '${widget.account.name} already matches'
            : '${widget.account.name} adjusted by ${Money.format(actual - widget.account.balance, signed: true)}',
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final current = account.isCreditCard ? account.outstanding : account.balance;
    return AlertDialog(
      title: Text('Reconcile ${account.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.isCreditCard
                  ? 'HisaabChat says you owe ${Money.format(current)}. What does your card statement say?'
                  : 'HisaabChat shows ${Money.format(current)}. How much is actually in ${account.name}?',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 16),
            AmountField(
              controller: _amount,
              hint: account.isCreditCard ? 'Actual amount owed' : 'Actual balance',
              autofocus: true,
              textInputAction: TextInputAction.done,
              errorText: _error,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _saving ? null : _submit, child: const Text('Adjust')),
      ],
    );
  }
}
