import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/amount_field.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/categories/categories_controller.dart';
import 'package:hisaabchat/features/categories/data/category.dart';
import 'package:hisaabchat/features/people/data/person.dart';
import 'package:hisaabchat/features/people/people_controller.dart';

/// "Write off": forget what's left with [person] (all or part of it) without
/// any money moving. What they owed you becomes an expense; what you owed
/// them becomes income.
Future<void> showWriteOffDialog(BuildContext context, Person person) => showDialog<void>(
  context: context,
  builder: (context) => _WriteOffDialog(person: person),
);

/// The category picked to start with: Gifts / Other for a loss, Other Income
/// for a gift, else the first one of that type.
TxnCategory? defaultWriteOffCategory(List<TxnCategory> categories, CategoryType type) {
  final options = categories.activeOf(type).where((c) => c.parentId == null).toList();
  final names = type == CategoryType.expense ? ['Gifts', 'Other'] : ['Other Income'];
  for (final name in names) {
    final match = options.where((c) => c.name == name).firstOrNull;
    if (match != null) return match;
  }
  return options.firstOrNull;
}

class _WriteOffDialog extends ConsumerStatefulWidget {
  const _WriteOffDialog({required this.person});

  final Person person;

  @override
  ConsumerState<_WriteOffDialog> createState() => _WriteOffDialogState();
}

class _WriteOffDialogState extends ConsumerState<_WriteOffDialog> {
  late final _amount = TextEditingController(
    text: Money.format(widget.person.balance.abs()).replaceAll('₹', '').replaceAll(',', ''),
  );
  String? _accountId;
  String? _categoryId;
  bool _saving = false;
  String? _error;

  bool get _theyOwe => widget.person.balance > 0;

  CategoryType get _type => _theyOwe ? CategoryType.expense : CategoryType.income;

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
    final categories = ref.read(categoriesProvider).value ?? const [];
    final categoryId = _categoryId ?? defaultWriteOffCategory(categories, _type)?.id;

    setState(() {
      _saving = true;
      _error = null;
    });
    final toast = AppToast.of(context);
    try {
      await ref
          .read(peopleProvider.notifier)
          .writeOff(widget.person.id, accountId: accountId, amount: amount, categoryId: categoryId);
      if (!mounted) return;
      Navigator.of(context).pop();
      toast.show('Wrote off ${Money.format(amount)} with ${widget.person.name}', kind: ToastKind.success);
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
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final options = categories.activeOf(_type);
    final selectedAccount = _accountId ?? accounts.firstOrNull?.id;
    final selectedCategory = _categoryId ?? defaultWriteOffCategory(categories, _type)?.id;
    final name = widget.person.name;
    final balance = Money.format(widget.person.balance.abs());

    return AlertDialog(
      title: Text('Write off with $name?'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _theyOwe
                    ? '$name owes you $balance. Writing it off means you won’t get it back: it’s counted as '
                          'spending, and $name’s balance goes down.'
                    : 'You owe $name $balance. Writing it off means you won’t pay it back: it’s counted as '
                          'income, and what you owe goes down.',
                style: TextStyle(color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              AmountField(controller: _amount, hint: 'Amount', allowZero: false),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('write-off-category'),
                initialValue: selectedCategory,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _theyOwe ? 'Count it as spending on' : 'Count it as income from',
                ),
                items: [for (final c in options) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('write-off-account'),
                initialValue: selectedAccount,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Show it in',
                  helperText: 'No money moves: this account’s balance stays the same',
                ),
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
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: colors.danger),
          child: const Text('Write off'),
        ),
      ],
    );
  }
}
