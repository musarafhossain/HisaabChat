import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/amount_field.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/people/data/person.dart';
import 'package:hisaabchat/features/people/people_controller.dart';

/// "Settle up": record the money that squares you up with [person]
/// (all of it, or part of it) into or out of one account.
Future<void> showSettleDialog(BuildContext context, Person person) => showDialog<void>(
  context: context,
  builder: (context) => _SettleDialog(person: person),
);

class _SettleDialog extends ConsumerStatefulWidget {
  const _SettleDialog({required this.person});

  final Person person;

  @override
  ConsumerState<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends ConsumerState<_SettleDialog> {
  late final _amount = TextEditingController(
    text: Money.format(widget.person.balance.abs()).replaceAll('₹', '').replaceAll(',', ''),
  );
  String? _accountId;
  bool _saving = false;
  String? _error;

  bool get _theyOwe => widget.person.balance > 0;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = AmountField.paiseOf(_amount);
    final outstanding = widget.person.balance.abs();
    if (amount == null || amount <= 0) return setState(() => _error = 'Enter an amount');
    if (amount > outstanding) return setState(() => _error = 'That’s more than ${Money.format(outstanding)}');
    final accountId = _accountId ?? ref.read(accountsProvider).value?.active.firstOrNull?.id;
    if (accountId == null) return setState(() => _error = 'Add an account first');

    setState(() {
      _saving = true;
      _error = null;
    });
    final toast = AppToast.of(context);
    try {
      await ref.read(peopleProvider.notifier).settle(widget.person.id, accountId: accountId, amount: amount);
      if (!mounted) return;
      Navigator.of(context).pop();
      toast.show(
        amount == outstanding ? 'Settled up with ${widget.person.name}' : 'Recorded ${Money.format(amount)}',
        kind: ToastKind.success,
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.fieldErrors.values.firstOrNull ?? error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accounts = ref.watch(accountsProvider).value?.active ?? const [];
    final selected = _accountId ?? accounts.firstOrNull?.id;
    final name = widget.person.name;

    return AlertDialog(
      title: Text('Settle up with $name'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _theyOwe
                  ? '$name owes you ${Money.format(widget.person.balance)}. How much did you get back?'
                  : 'You owe $name ${Money.format(-widget.person.balance)}. How much did you pay back?',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            AmountField(controller: _amount, hint: 'Amount', allowZero: false),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              decoration: InputDecoration(labelText: _theyOwe ? 'Received into' : 'Paid from'),
              items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
              onChanged: (value) => setState(() => _accountId = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: colors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_theyOwe ? 'Record received' : 'Record paid'),
        ),
      ],
    );
  }
}
