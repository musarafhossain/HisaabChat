import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/format/dates.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/shake.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/adaptive_sheet.dart';
import 'package:hisaabchat/core/widgets/amount_field.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/categories/categories_controller.dart';
import 'package:hisaabchat/features/categories/data/category.dart';
import 'package:hisaabchat/features/recurring/data/recurring.dart';
import 'package:hisaabchat/features/recurring/recurring_controller.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';

/// Create or edit a recurring rule (Settings → Recurring).
Future<void> showRuleForm(BuildContext context, {RecurringRule? existing}) =>
    showAdaptiveSheet<void>(context, child: RuleForm(existing: existing), maxDialogWidth: 560);

class RuleForm extends ConsumerStatefulWidget {
  const RuleForm({super.key, this.existing});

  final RecurringRule? existing;

  @override
  ConsumerState<RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends ConsumerState<RuleForm> {
  final _formKey = GlobalKey<FormState>();
  late TxnType _type = widget.existing?.type ?? TxnType.expense;
  late final _amount = TextEditingController(
    text: widget.existing == null ? '' : Money.format(widget.existing!.amount).replaceAll('₹', '').replaceAll(',', ''),
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String? _accountId = widget.existing?.account.id;
  late String? _toAccountId = widget.existing?.toAccount?.id;
  late String? _categoryId = widget.existing?.category?.id;
  late Frequency _frequency = widget.existing?.frequency ?? Frequency.monthly;
  late DateTime _startDate = widget.existing?.startDate ?? DateTime.now();
  late DateTime? _endDate = widget.existing?.endDate;
  late bool _autoAdd = widget.existing?.autoCreate ?? true;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};
  int _shake = 0;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial, {DateTime? first}) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(2000),
    lastDate: DateTime(DateTime.now().year + 10),
  );

  Future<void> _save() async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    final missing = <String, String>{
      if (_accountId == null) 'accountId': 'Choose an account',
      if (_type == TxnType.transfer && _toAccountId == null) 'toAccountId': 'Choose where the money goes',
      if (_type != TxnType.transfer && _categoryId == null) 'categoryId': 'Choose a category',
    };
    if (!_formKey.currentState!.validate() || missing.isNotEmpty) {
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
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      'frequency': _frequency.api,
      'dayOfMonth': _frequency == Frequency.monthly ? _startDate.day : null,
      'startDate': isoDateOf(_startDate),
      'endDate': _endDate == null ? null : isoDateOf(_endDate!),
      'autoCreate': _autoAdd,
    };

    setState(() => _saving = true);
    final mutations = ref.read(recurringMutationsProvider);
    try {
      if (_isEdit) {
        await mutations.update(widget.existing!.id, body);
      } else {
        await mutations.create(body);
      }
      if (mounted) Navigator.of(context).pop();
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

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
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
    final accounts = ref.watch(accountsProvider).value?.active ?? const [];
    final categories = (ref.watch(categoriesProvider).value ?? const <TxnCategory>[]).activeOf(
      _type == TxnType.income ? CategoryType.income : CategoryType.expense,
    );

    DropdownButtonFormField<String> dropdown(
      String field,
      String label,
      String? value,
      List<(String, String)> items,
      ValueChanged<String?> onChanged,
    ) {
      final valid = items.any((i) => i.$1 == value) ? value : null;
      return DropdownButtonFormField<String>(
        key: ValueKey('$field-$_type-${items.length}-$valid'),
        initialValue: valid,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, errorText: _fieldErrors[field]),
        items: [for (final (id, name) in items) DropdownMenuItem(value: id, child: Text(name))],
        onChanged: onChanged,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Shake(
        trigger: _shake,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEdit ? 'Edit recurring' : 'New recurring',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SegmentedButton<TxnType>(
                segments: const [
                  ButtonSegment(value: TxnType.expense, label: Text('Expense')),
                  ButtonSegment(value: TxnType.income, label: Text('Income')),
                  ButtonSegment(value: TxnType.transfer, label: Text('Transfer')),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _categoryId = null;
                }),
              ),
              const SizedBox(height: 16),
              AmountField(controller: _amount, hint: 'Amount', allowZero: false, errorText: _fieldErrors['amount']),
              const SizedBox(height: 12),
              dropdown(
                'accountId',
                _type == TxnType.transfer ? 'From account' : 'Account',
                _accountId,
                [for (final a in accounts) (a.id, a.name)],
                (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 12),
              if (_type == TxnType.transfer)
                dropdown(
                  'toAccountId',
                  'To account',
                  _toAccountId,
                  [for (final a in accounts) (a.id, a.name)],
                  (v) => setState(() => _toAccountId = v),
                )
              else
                dropdown(
                  'categoryId',
                  'Category',
                  _categoryId,
                  [for (final c in categories) (c.id, c.name)],
                  (v) => setState(() => _categoryId = v),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Note (optional)', counterText: ''),
              ),
              const SectionLabel('Schedule'),
              DropdownButtonFormField<Frequency>(
                initialValue: _frequency,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Repeats'),
                items: [for (final f in Frequency.values) DropdownMenuItem(value: f, child: Text(f.label))],
                onChanged: (v) => setState(() => _frequency = v ?? Frequency.monthly),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: const Icon(AppIcons.today),
                title: Text(
                  _frequency == Frequency.monthly
                      ? 'Starts ${Dates.dayMonth(_startDate)} · on the ${ordinal(_startDate.day)}'
                      : 'Starts ${Dates.dayMonth(_startDate)}',
                ),
                trailing: const Icon(AppIcons.expand),
                onTap: () async {
                  final picked = await _pick(_startDate);
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: const Icon(AppIcons.month),
                title: Text(_endDate == null ? 'No end date' : 'Ends ${Dates.dayMonth(_endDate!)}'),
                subtitle: _fieldErrors['endDate'] == null
                    ? null
                    : Text(_fieldErrors['endDate']!, style: TextStyle(color: colors.danger)),
                trailing: _endDate == null
                    ? const Icon(AppIcons.expand)
                    : IconButton(
                        tooltip: 'Remove end date',
                        icon: const Icon(AppIcons.close),
                        onPressed: () => setState(() => _endDate = null),
                      ),
                onTap: () async {
                  final picked = await _pick(_endDate ?? _startDate, first: _startDate);
                  if (picked != null) setState(() => _endDate = picked);
                },
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                value: _autoAdd,
                onChanged: (v) => setState(() => _autoAdd = v),
                title: const Text('Add automatically'),
                subtitle: Text(
                  _autoAdd ? 'Added on each due date' : 'Remind me on Home to confirm or skip',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: colors.danger)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEdit ? 'Save changes' : 'Create'),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _run(
                              () => ref.read(recurringMutationsProvider).update(widget.existing!.id, {
                                'isActive': !widget.existing!.isActive,
                              }),
                            ),
                      icon: Icon(widget.existing!.isActive ? AppIcons.sending : AppIcons.recurring),
                      label: Text(widget.existing!.isActive ? 'Pause' : 'Resume'),
                    ),
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _run(() => ref.read(recurringMutationsProvider).delete(widget.existing!.id)),
                      style: TextButton.styleFrom(foregroundColor: colors.danger),
                      icon: const Icon(AppIcons.delete),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
