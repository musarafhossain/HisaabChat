import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/shake.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/adaptive_sheet.dart';
import 'package:hisaabchat/core/widgets/amount_field.dart';
import 'package:hisaabchat/core/widgets/color_palette.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/auth/presentation/auth_scaffold.dart';

/// Opens the add/edit account form: a bottom sheet on phones, a dialog on
/// wider windows. Returns the saved account, or null if dismissed.
Future<Account?> showAccountForm(BuildContext context, {Account? existing, String? intro}) {
  final form = AccountForm(existing: existing, intro: intro);
  return showAdaptiveSheet<Account>(context, child: form);
}

class AccountForm extends ConsumerStatefulWidget {
  const AccountForm({super.key, this.existing, this.intro});

  final Account? existing;

  /// Optional line under the title explaining why the form opened.
  final String? intro;

  @override
  ConsumerState<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late AccountType _type = widget.existing?.type ?? AccountType.cash;
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _amount = TextEditingController(text: _initialAmountText());
  late final _limit = TextEditingController(
    text: widget.existing?.creditLimit == null ? '' : _plain(widget.existing!.creditLimit!),
  );
  late Color _color = widget.existing?.color ?? _type.defaultColor;
  late bool _includeInTotal = widget.existing?.includeInTotal ?? true;
  late bool _colorTouched = widget.existing != null;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};
  int _shake = 0;

  bool get _isEdit => widget.existing != null;

  String _initialAmountText() {
    final existing = widget.existing;
    if (existing == null) return '';
    // Cards are entered as "amount outstanding" (stored as a negative balance).
    final value = existing.isCreditCard ? -existing.openingBalance : existing.openingBalance;
    return _plain(value);
  }

  static String _plain(int paise) => Money.format(paise).replaceAll('₹', '').replaceAll(',', '');

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _limit.dispose();
    super.dispose();
  }

  void _selectType(AccountType type) => setState(() {
    _type = type;
    if (!_colorTouched) _color = type.defaultColor;
  });

  Future<void> _save() async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    if (!_formKey.currentState!.validate()) {
      setState(() => _shake++);
      return;
    }

    final amount = AmountField.paiseOf(_amount) ?? 0;
    final body = <String, Object?>{
      'name': _name.text.trim(),
      'type': _type.api,
      'openingBalance': _type == AccountType.creditCard ? -amount : amount,
      'color': toHexColor(_color),
      'includeInTotal': _includeInTotal,
      'creditLimit': _type == AccountType.creditCard ? AmountField.paiseOf(_limit) : null,
      if (!_isEdit || widget.existing!.type != _type) 'icon': _type.defaultIcon,
    };

    setState(() => _saving = true);
    final controller = ref.read(accountsProvider.notifier);
    try {
      final saved = _isEdit ? await controller.updateAccount(widget.existing!.id, body) : await controller.create(body);
      if (mounted) Navigator.of(context).pop(saved);
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final isCard = _type == AccountType.creditCard;

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
                _isEdit ? 'Edit account' : 'New account',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (widget.intro != null) ...[
                const SizedBox(height: 6),
                Text(widget.intro!, style: TextStyle(color: colors.textSecondary)),
              ],
              const SectionLabel('Type'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in AccountType.values)
                    ChoiceChip(
                      avatar: Icon(AppIcons.byKey(type.defaultIcon), size: 18, fill: _type == type ? 1 : 0),
                      label: Text(type.label),
                      selected: _type == type,
                      showCheckmark: false,
                      labelStyle: _type == type ? theme.chipTheme.secondaryLabelStyle : null,
                      onSelected: (_) => _selectType(type),
                    ),
                ],
              ),
              const SectionLabel('Name'),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: switch (_type) {
                    AccountType.cash => 'e.g. Cash',
                    AccountType.bank => 'e.g. SBI Savings',
                    AccountType.wallet => 'e.g. Paytm, PhonePe',
                    AccountType.creditCard => 'e.g. HDFC Card',
                    AccountType.savings => 'e.g. Emergency Fund',
                    AccountType.other => 'Account name',
                  },
                  errorText: _fieldErrors['name'],
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a name' : null,
              ),
              SectionLabel(isCard ? 'Amount outstanding now' : (_isEdit ? 'Opening balance' : 'Current balance')),
              AmountField(
                controller: _amount,
                hint: '0',
                required: false,
                errorText: _fieldErrors['openingBalance'],
                helperText: _isEdit
                    ? 'Changing this moves the current balance by the same amount.'
                    : (isCard ? 'What you owe on the card today.' : 'How much is in it today.'),
              ),
              if (isCard) ...[
                const SectionLabel('Credit limit (optional)'),
                AmountField(controller: _limit, hint: 'e.g. 100000', required: false),
              ],
              const SectionLabel('Color'),
              ColorPalettePicker(
                selected: _color,
                onChanged: (color) => setState(() {
                  _color = color;
                  _colorTouched = true;
                }),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include in total balance'),
                subtitle: Text(
                  'Turn off for money you don’t want counted, like an emergency fund.',
                  style: TextStyle(color: colors.textSecondary),
                ),
                value: _includeInTotal,
                onChanged: (value) => setState(() => _includeInTotal = value),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 12)],
              SubmitButton(label: _isEdit ? 'Save changes' : 'Add account', loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
