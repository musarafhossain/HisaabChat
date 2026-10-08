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
import 'package:hisaabchat/features/accounts/data/account.dart' show toHexColor;
import 'package:hisaabchat/features/auth/presentation/auth_scaffold.dart';
import 'package:hisaabchat/features/budgets/budgets_controller.dart';
import 'package:hisaabchat/features/budgets/data/budget.dart';
import 'package:hisaabchat/features/categories/categories_controller.dart';
import 'package:hisaabchat/features/categories/data/category.dart';

/// Ready-made budgets from the PRD (Room Rent, Food & Groceries, Bike EMI +
/// Petrol, Education), matched to the default categories by name.
@immutable
class BudgetTemplate {
  const BudgetTemplate(this.name, this.kind, this.categoryNames, this.icon, this.hint);

  final String name;
  final BudgetKind kind;
  final List<String> categoryNames;
  final String icon;
  final String hint;

  static const all = [
    BudgetTemplate('Room Rent', BudgetKind.fixed, ['Room Rent'], 'home', 'Your monthly rent'),
    BudgetTemplate(
      'Food & Groceries',
      BudgetKind.variable,
      ['Food & Groceries', 'Eating Out'],
      'shopping_cart',
      'Groceries and eating out',
    ),
    BudgetTemplate(
      'Bike EMI + Petrol',
      BudgetKind.variable,
      ['Bike EMI', 'Petrol', 'Bike Maintenance'],
      'two_wheeler',
      'EMI, petrol and servicing together',
    ),
    BudgetTemplate('Education', BudgetKind.fixed, ['Education'], 'school', 'Fees, books and courses'),
  ];
}

/// Create or edit a budget (sheet on phones, dialog on wider windows).
Future<void> showBudgetForm(BuildContext context, {BudgetStatus? existing, BudgetTemplate? template}) {
  final form = BudgetForm(existing: existing, template: template);
  return showAdaptiveSheet<void>(context, child: form, maxDialogWidth: 560);
}

class BudgetForm extends ConsumerStatefulWidget {
  const BudgetForm({super.key, this.existing, this.template});

  final BudgetStatus? existing;
  final BudgetTemplate? template;

  @override
  ConsumerState<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends ConsumerState<BudgetForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? widget.template?.name ?? '');
  late final _amount = TextEditingController(
    text: widget.existing == null ? '' : Money.format(widget.existing!.amount).replaceAll('₹', '').replaceAll(',', ''),
  );
  late BudgetKind _kind = widget.existing?.kind ?? widget.template?.kind ?? BudgetKind.variable;
  late int _alertPercent = widget.existing?.alertPercent ?? 80;
  late Color _color = widget.existing?.color ?? kPaletteColors.first;
  late Set<String> _categoryIds = {...?widget.existing?.categories.map((c) => c.id)};
  bool _templateApplied = false;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};
  int _shake = 0;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Picks the template's categories once the category list is available.
  void _applyTemplate(List<TxnCategory> categories) {
    final template = widget.template;
    if (_templateApplied || template == null) return;
    _templateApplied = true;
    final picked = categories.where(
      (c) => template.categoryNames.contains(c.name) && c.type == CategoryType.expense && c.budgetId == null,
    );
    _categoryIds = {for (final c in picked) c.id};
    if (picked.isNotEmpty) _color = picked.first.color;
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    final valid = _formKey.currentState!.validate();
    if (!valid || _categoryIds.isEmpty) {
      setState(() {
        _shake++;
        if (_categoryIds.isEmpty) _fieldErrors = const {'categoryIds': 'Choose at least one category'};
      });
      return;
    }

    final categories = ref.read(categoriesProvider).value ?? const <TxnCategory>[];
    final first = categories.where((c) => _categoryIds.contains(c.id)).firstOrNull;
    final body = <String, Object?>{
      'name': _name.text.trim(),
      'amount': AmountField.paiseOf(_amount),
      'kind': _kind.api,
      'alertPercent': _alertPercent,
      'color': toHexColor(_color),
      'icon': widget.template?.icon ?? widget.existing?.icon ?? first?.icon ?? 'savings',
      'categoryIds': _categoryIds.toList(),
    };

    setState(() => _saving = true);
    final mutations = ref.read(budgetMutationsProvider);
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final all = ref.watch(categoriesProvider).value ?? const <TxnCategory>[];
    _applyTemplate(all);
    final expense = all.where((c) => c.type == CategoryType.expense && !c.archived).toList();
    String? takenBy(TxnCategory c) {
      if (c.budgetId == null || c.budgetId == widget.existing?.id) return null;
      return ref
              .read(budgetsOverviewProvider(null))
              .value
              ?.budgets
              .where((b) => b.id == c.budgetId)
              .firstOrNull
              ?.name ??
          'another budget';
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
                _isEdit ? 'Edit budget' : 'New budget',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (widget.template != null) ...[
                const SizedBox(height: 4),
                Text(widget.template!.hint, style: TextStyle(color: colors.textSecondary)),
              ],
              const SectionLabel('Name'),
              TextFormField(
                controller: _name,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. Food & Groceries',
                  errorText: _fieldErrors['name'],
                  counterText: '',
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SectionLabel('Monthly amount'),
              AmountField(
                controller: _amount,
                hint: 'e.g. 4000',
                autofocus: widget.template != null,
                errorText: _fieldErrors['amount'],
                helperText: _isEdit ? 'Your default; you can change a single month from the budget page.' : null,
              ),
              const SectionLabel('Type'),
              SegmentedButton<BudgetKind>(
                segments: const [
                  ButtonSegment(value: BudgetKind.variable, label: Text('Variable')),
                  ButtonSegment(value: BudgetKind.fixed, label: Text('Fixed')),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => setState(() => _kind = selection.first),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  _kind == BudgetKind.variable ? '${_kind.hint}. Shows a safe-to-spend per day.' : _kind.hint,
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
              ),
              const SectionLabel('Categories it covers'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in expense)
                    Builder(
                      builder: (context) {
                        final taken = takenBy(category);
                        final selected = _categoryIds.contains(category.id);
                        return FilterChip(
                          avatar: Icon(
                            AppIcons.byKey(category.icon),
                            size: 18,
                            color: taken == null ? category.color : colors.textSecondary,
                            fill: selected ? 1 : 0,
                          ),
                          label: Text(taken == null ? category.name : '${category.name} · in $taken'),
                          selected: selected,
                          showCheckmark: false,
                          labelStyle: selected ? theme.chipTheme.secondaryLabelStyle : null,
                          onSelected: taken != null
                              ? null
                              : (on) => setState(() {
                                  on ? _categoryIds.add(category.id) : _categoryIds.remove(category.id);
                                  _fieldErrors = const {};
                                }),
                        );
                      },
                    ),
                ],
              ),
              if (_fieldErrors['categoryIds'] != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 6),
                  child: Text(_fieldErrors['categoryIds']!, style: TextStyle(fontSize: 12, color: colors.danger)),
                ),
              SectionLabel('Warn me at $_alertPercent%'),
              Slider(
                value: _alertPercent.toDouble(),
                min: 50,
                max: 100,
                divisions: 10,
                label: '$_alertPercent%',
                onChanged: (value) => setState(() => _alertPercent = value.round()),
              ),
              const SectionLabel('Color'),
              ColorPalettePicker(selected: _color, onChanged: (color) => setState(() => _color = color)),
              const SizedBox(height: 20),
              if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 12)],
              SubmitButton(label: _isEdit ? 'Save changes' : 'Create budget', loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
