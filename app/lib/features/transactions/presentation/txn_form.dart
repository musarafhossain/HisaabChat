import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/format/dates.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/shake.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/amount_field.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/core/widgets/window_class.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/auth/presentation/auth_scaffold.dart';
import 'package:hisaabchat/features/categories/categories_controller.dart';
import 'package:hisaabchat/features/categories/data/category.dart';
import 'package:hisaabchat/features/recurring/data/recurring.dart';
import 'package:hisaabchat/features/recurring/recurring_controller.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:hisaabchat/features/transactions/transactions_controller.dart';

/// Values to start a new transaction with (from the composer's 📎 or a FAB).
class TxnDraft {
  const TxnDraft({this.type = TxnType.expense, this.amount, this.accountId, this.categoryId, this.note});

  final TxnType type;
  final int? amount;
  final String? accountId;
  final String? categoryId;
  final String? note;
}

/// Opens the full form: full-screen page on phones, dialog on wider windows.
/// Completes with true when something was saved or deleted.
Future<bool?> showTxnForm(BuildContext context, {Txn? existing, TxnDraft? draft}) {
  final title = existing == null ? 'New transaction' : 'Edit transaction';
  if (context.windowClass == WindowClass.compact) {
    return Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
          ),
          body: TxnForm(existing: existing, draft: draft, onDone: (saved) => Navigator.of(context).pop(saved)),
        ),
      ),
    );
  }
  return showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: TxnForm(existing: existing, draft: draft, onDone: (saved) => Navigator.of(context).pop(saved)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows a toast with Undo after deleting [txns].
void showDeletedToast(BuildContext context, WidgetRef ref, List<Txn> txns) {
  final toast = AppToast.of(context);
  // Read now: the calling widget (e.g. the edit form) may be gone when Undo is tapped.
  final mutations = ref.read(txnMutationsProvider);
  final label = txns.length == 1
      ? 'Deleted ${Money.format(txns.single.amount)} ${txns.single.labelFor(null)}'
      : 'Deleted ${txns.length} transactions';
  toast.show(
    label,
    kind: ToastKind.success,
    actionLabel: 'Undo',
    onAction: () async {
      for (final txn in txns) {
        await mutations.restore(txn);
      }
    },
  );
}

class TxnForm extends ConsumerStatefulWidget {
  const TxnForm({required this.onDone, super.key, this.existing, this.draft});

  final Txn? existing;
  final TxnDraft? draft;
  final ValueChanged<bool> onDone;

  @override
  ConsumerState<TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends ConsumerState<TxnForm> {
  final _formKey = GlobalKey<FormState>();
  late TxnType _type = widget.existing?.type ?? widget.draft?.type ?? TxnType.expense;
  late final _amount = TextEditingController(text: _initialAmount());
  late final _note = TextEditingController(text: widget.existing?.note ?? widget.draft?.note ?? '');
  late String? _accountId = widget.existing?.account.id ?? widget.draft?.accountId;
  late String? _toAccountId = widget.existing?.toAccount?.id;
  late String? _categoryId = widget.existing?.category?.id ?? widget.draft?.categoryId;
  late DateTime _date = widget.existing?.localDate ?? DateTime.now();

  /// New transactions only: repeat on this schedule (null = once).
  Frequency? _repeat;

  /// Repeat: add it automatically, or remind me to confirm each time.
  bool _autoAdd = true;
  bool _showAllCategories = false;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};
  int _shake = 0;

  bool get _isEdit => widget.existing != null;

  /// Adjustments and lend/borrow entries can only be viewed and deleted here.
  bool get _isReadOnly => widget.existing?.type == TxnType.adjustment || (widget.existing?.type.isPeople ?? false);

  String _initialAmount() {
    final paise = widget.existing?.amount ?? widget.draft?.amount;
    return paise == null ? '' : Money.format(paise).replaceAll('₹', '').replaceAll(',', '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setType(TxnType type) => setState(() {
    _type = type;
    _categoryId = null;
    _fieldErrors = const {};
  });

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (!mounted) return;
    setState(() {
      final t = time ?? TimeOfDay.fromDateTime(_date);
      _date = DateTime(date.year, date.month, date.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    final valid = _formKey.currentState!.validate();
    final missing = <String, String>{
      if (_accountId == null) 'accountId': 'Choose an account',
      if (_type == TxnType.transfer && _toAccountId == null) 'toAccountId': 'Choose where the money went',
      if (_type == TxnType.transfer && _toAccountId != null && _toAccountId == _accountId)
        'toAccountId': 'Choose two different accounts',
      if (_type != TxnType.transfer && _categoryId == null) 'categoryId': 'Choose a category',
    };
    if (!valid || missing.isNotEmpty) {
      setState(() {
        _fieldErrors = missing;
        _shake++;
      });
      return;
    }

    final body = <String, Object?>{
      'type': _type.api,
      'amount': AmountField.paiseOf(_amount),
      'accountId': _accountId,
      'toAccountId': _type == TxnType.transfer ? _toAccountId : null,
      'categoryId': _type == TxnType.transfer ? null : _categoryId,
      'date': _date.toUtc().toIso8601String(),
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
    };

    setState(() => _saving = true);
    final mutations = ref.read(txnMutationsProvider);
    try {
      if (_isEdit) {
        await mutations.update(widget.existing!.id, body);
      } else {
        final txn = await mutations.create(body);
        if (_repeat != null && !await _makeRecurring(txn)) return;
      }
      unawaited(HapticFeedback.lightImpact());
      widget.onDone(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _shake++;
        _fieldErrors = error.fieldErrors;
        _error = error.fieldErrors.isEmpty ? error.message : null;
      });
    }
  }

  /// Turns the saved transaction into the first of a recurring rule.
  /// false (with the error shown) if the rule couldn't be created.
  Future<bool> _makeRecurring(Txn txn) async {
    try {
      await ref.read(recurringMutationsProvider).create({
        'type': txn.type.api,
        'amount': txn.amount,
        'accountId': txn.account.id,
        'toAccountId': txn.toAccount?.id,
        'categoryId': txn.category?.id,
        'note': txn.note,
        'frequency': _repeat!.api,
        'dayOfMonth': _repeat == Frequency.monthly ? _date.day : null,
        'startDate': isoDateOf(_date),
        'autoCreate': _autoAdd,
        'linkTransactionId': txn.id,
      });
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Saved once, but it couldn’t be set to repeat: ${error.message}';
        });
      }
      return false;
    }
  }

  Future<void> _delete() async {
    final txn = widget.existing!;
    setState(() => _saving = true);
    try {
      await ref.read(txnMutationsProvider).delete(txn.id);
      if (!mounted) return;
      showDeletedToast(context, ref, [txn]);
      widget.onDone(true);
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
    final colors = context.colors;
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value?.active ?? const <Account>[];
    final categories = ref.watch(categoriesProvider).value ?? const <TxnCategory>[];

    if (_isReadOnly) return _readOnlyInfo(context);

    final typeColor = switch (_type) {
      TxnType.income => colors.income,
      TxnType.transfer => colors.transfer,
      _ => colors.expense,
    };
    final pickable = categories.activeOf(_type == TxnType.income ? CategoryType.income : CategoryType.expense);
    // Keep the current category visible even if it was archived later.
    final current = categories.byId(_categoryId);
    if (current != null && !pickable.contains(current)) pickable.insert(0, current);
    final visible = _showAllCategories || pickable.length <= 10 ? pickable : pickable.take(9).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Shake(
        trigger: _shake,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TxnType>(
                segments: const [
                  ButtonSegment(value: TxnType.expense, icon: Icon(AppIcons.expense), label: Text('Expense')),
                  ButtonSegment(value: TxnType.income, icon: Icon(AppIcons.income), label: Text('Income')),
                  ButtonSegment(value: TxnType.transfer, icon: Icon(AppIcons.transfer), label: Text('Transfer')),
                ],
                selected: {_type},
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: typeColor.withValues(alpha: 0.15),
                  selectedForegroundColor: typeColor,
                ),
                onSelectionChanged: (selection) => _setType(selection.first),
              ),
              const SizedBox(height: 16),
              AmountField(
                controller: _amount,
                hint: 'Amount',
                allowZero: false,
                autofocus: !_isEdit,
                errorText: _fieldErrors['amount'],
              ),
              if (_type != TxnType.transfer) ...[
                const SectionLabel('Category'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in visible)
                      ChoiceChip(
                        avatar: Icon(
                          AppIcons.byKey(category.icon),
                          size: 18,
                          color: category.color,
                          fill: _categoryId == category.id ? 1 : 0,
                        ),
                        label: Text(category.name),
                        selected: _categoryId == category.id,
                        showCheckmark: false,
                        labelStyle: _categoryId == category.id ? theme.chipTheme.secondaryLabelStyle : null,
                        onSelected: (_) => setState(() => _categoryId = category.id),
                      ),
                    if (visible.length < pickable.length)
                      ActionChip(
                        avatar: const Icon(AppIcons.expand, size: 18),
                        label: Text('More (${pickable.length - visible.length})'),
                        onPressed: () => setState(() => _showAllCategories = true),
                      ),
                  ],
                ),
                if (_fieldErrors['categoryId'] != null) _fieldError(_fieldErrors['categoryId']!),
              ],
              SectionLabel(_type == TxnType.transfer ? 'From account' : 'Account'),
              _accountDropdown(accounts, _accountId, (id) => setState(() => _accountId = id), 'accountId'),
              if (_type == TxnType.transfer) ...[
                const SectionLabel('To account'),
                _accountDropdown(
                  accounts.where((a) => a.id != _accountId).toList(),
                  _toAccountId == _accountId ? null : _toAccountId,
                  (id) => setState(() => _toAccountId = id),
                  'toAccountId',
                ),
              ],
              const SectionLabel('Date & time'),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                tileColor: colors.inputFill,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                leading: const Icon(AppIcons.today),
                title: Text(Dates.formLabel(_date)),
                trailing: const Icon(AppIcons.expand),
                onTap: _pickDate,
              ),
              if (!_isEdit) ...[
                const SectionLabel('Repeat'),
                DropdownButtonFormField<Frequency?>(
                  initialValue: _repeat,
                  isExpanded: true,
                  decoration: const InputDecoration(prefixIcon: Icon(AppIcons.recurring)),
                  items: [
                    const DropdownMenuItem(child: Text('Doesn’t repeat')),
                    for (final f in Frequency.values)
                      DropdownMenuItem(
                        value: f,
                        child: Text(f == Frequency.monthly ? 'Monthly on the ${ordinal(_date.day)}' : f.label),
                      ),
                  ],
                  onChanged: (value) => setState(() => _repeat = value),
                ),
                if (_repeat != null)
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    value: _autoAdd,
                    onChanged: (value) => setState(() => _autoAdd = value),
                    title: const Text('Add automatically'),
                    subtitle: Text(
                      _autoAdd ? 'Added on each due date' : 'Remind me on Home to confirm or skip',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
              ] else if (widget.existing!.isRecurring)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(AppIcons.recurring, size: 18, color: colors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Repeats. Change the schedule in Settings → Recurring.',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              const SectionLabel('Note (optional)'),
              TextFormField(
                controller: _note,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'e.g. Big Bazaar', prefixIcon: Icon(AppIcons.note)),
              ),
              const SizedBox(height: 8),
              if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 12)],
              SubmitButton(label: _isEdit ? 'Save changes' : 'Save', loading: _saving, onPressed: _save),
              if (_isEdit) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _saving ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: colors.danger),
                  icon: const Icon(AppIcons.delete),
                  label: const Text('Delete transaction'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountDropdown(List<Account> accounts, String? value, ValueChanged<String?> onChanged, String field) {
    final valid = accounts.any((a) => a.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('$field-${accounts.length}-$valid'),
      initialValue: valid,
      isExpanded: true,
      hint: const Text('Choose an account'),
      decoration: InputDecoration(errorText: _fieldErrors[field]),
      items: [
        for (final account in accounts)
          DropdownMenuItem(
            value: account.id,
            child: Row(
              children: [
                Icon(AppIcons.byKey(account.icon), size: 20, color: account.color, fill: 1),
                const SizedBox(width: 10),
                Expanded(child: Text(account.name, overflow: TextOverflow.ellipsis)),
                Text(
                  Money.format(account.balance),
                  style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _fieldError(String message) => Padding(
    padding: const EdgeInsets.only(left: 12, top: 6),
    child: Text(message, style: TextStyle(fontSize: 12, color: context.colors.danger)),
  );

  /// Adjustments come from "Reconcile balance": they can be deleted, not edited.
  Widget _readOnlyInfo(BuildContext context) {
    final txn = widget.existing!;
    final colors = context.colors;
    if (txn.type.isPeople) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(AppIcons.people),
              title: Text('${txn.labelFor(null)} · ${Money.format(txn.amount)}'),
              subtitle: Text('${txn.account.name} · ${Dates.formLabel(txn.localDate)}'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Lend & borrow entries live in ${txn.person?.name ?? 'the person'}’s chat under People. '
                'To change one, delete it and add it again.',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            if (_error != null) FormErrorBanner(_error!),
            TextButton.icon(
              onPressed: _saving ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: colors.danger),
              icon: const Icon(AppIcons.delete),
              label: const Text('Delete entry'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(AppIcons.reconcile),
            title: Text(
              '${txn.adjustmentIncrease ?? false ? 'Increased' : 'Decreased'} by ${Money.format(txn.amount)}',
            ),
            subtitle: Text('${txn.account.name} · ${Dates.formLabel(txn.localDate)}'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Balance adjustments are created by “Reconcile balance” and can’t be edited. '
              'Delete it to undo the adjustment.',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          if (_error != null) FormErrorBanner(_error!),
          TextButton.icon(
            onPressed: _saving ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            icon: const Icon(AppIcons.delete),
            label: const Text('Delete adjustment'),
          ),
        ],
      ),
    );
  }
}
