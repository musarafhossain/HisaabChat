import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/motion.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/amount_field.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/budgets/budgets_controller.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_form.dart' show BudgetTemplate;
import 'package:hisaabchat/features/categories/categories_controller.dart';
import 'package:hisaabchat/features/categories/data/category.dart';

/// First-run setup (docs/03-AppFlow.md §2): month start → accounts →
/// budgets. Every step can be skipped; finishing (or skipping) marks the
/// user as onboarded and the router moves on to Home.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// Starter accounts offered on step 2.
const List<(AccountType, String, String)> _starterAccounts = [
  (AccountType.cash, 'Cash', 'Cash in hand'),
  (AccountType.bank, 'Bank', 'Savings account balance'),
  (AccountType.wallet, 'UPI', 'UPI / wallet balance'),
];

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _titles = ['Your month', 'Your money', 'Your budgets'];

  int _step = 0;
  bool _forward = true;
  bool _busy = false;
  String? _error;

  late int _monthStart = ref.read(authControllerProvider).value?.monthStartDay ?? 1;

  final Map<AccountType, bool> _accountOn = {
    AccountType.cash: true,
    AccountType.bank: false,
    AccountType.wallet: false,
  };
  final Map<AccountType, TextEditingController> _accountAmount = {
    for (final (type, _, _) in _starterAccounts) type: TextEditingController(),
  };
  final _createdAccounts = <AccountType>{};

  final Map<String, bool> _budgetOn = {for (final t in BudgetTemplate.all) t.name: false};
  final Map<String, TextEditingController> _budgetAmount = {
    for (final t in BudgetTemplate.all) t.name: TextEditingController(),
  };
  final _createdBudgets = <String>{};
  final _budgetErrors = <String, String>{};

  @override
  void dispose() {
    for (final c in [..._accountAmount.values, ..._budgetAmount.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _go(int step) => setState(() {
    _forward = step > _step;
    _step = step;
    _error = null;
  });

  Future<void> _next() => _run(() async {
    switch (_step) {
      case 0:
        final user = ref.read(authControllerProvider).value;
        if (user != null && user.monthStartDay != _monthStart) {
          await ref.read(authControllerProvider.notifier).updateProfile({'monthStartDay': _monthStart});
        }
        _go(1);
      case 1:
        await _createAccounts();
        _go(2);
      case 2:
        if (await _createBudgets()) await _finish();
    }
  });

  Future<void> _createAccounts() async {
    final existing = ref.read(accountsProvider).value?.active ?? const [];
    if (existing.isNotEmpty) return;
    final controller = ref.read(accountsProvider.notifier);
    for (final (type, name, _) in _starterAccounts) {
      if (!_accountOn[type]! || _createdAccounts.contains(type)) continue;
      await controller.create({
        'name': name,
        'type': type.api,
        'openingBalance': AmountField.paiseOf(_accountAmount[type]!) ?? 0,
        'icon': type.defaultIcon,
        'color': toHexColor(type.defaultColor),
      });
      _createdAccounts.add(type);
    }
  }

  /// Creates the ticked templates; false when an amount is missing.
  Future<bool> _createBudgets() async {
    final categories = ref.read(categoriesProvider).value ?? const <TxnCategory>[];
    final errors = <String, String>{};
    for (final template in _availableTemplates(categories)) {
      if (!_budgetOn[template.name]! || _createdBudgets.contains(template.name)) continue;
      final amount = AmountField.paiseOf(_budgetAmount[template.name]!);
      if (amount == null || amount <= 0) errors[template.name] = 'Enter a monthly amount';
    }
    setState(
      () => _budgetErrors
        ..clear()
        ..addAll(errors),
    );
    if (errors.isNotEmpty) return false;

    final mutations = ref.read(budgetMutationsProvider);
    for (final template in _availableTemplates(categories)) {
      if (!_budgetOn[template.name]! || _createdBudgets.contains(template.name)) continue;
      final picked = _freeCategories(template, categories);
      await mutations.create({
        'name': template.name,
        'amount': AmountField.paiseOf(_budgetAmount[template.name]!),
        'kind': template.kind.api,
        'alertPercent': 80,
        'color': toHexColor(picked.first.color),
        'icon': template.icon,
        'categoryIds': [for (final c in picked) c.id],
      });
      _createdBudgets.add(template.name);
    }
    return true;
  }

  Future<void> _finish() => ref.read(authControllerProvider.notifier).completeOnboarding();

  static List<TxnCategory> _freeCategories(BudgetTemplate template, List<TxnCategory> categories) => [
    for (final c in categories)
      if (template.categoryNames.contains(c.name) &&
          c.type == CategoryType.expense &&
          !c.archived &&
          c.budgetId == null)
        c,
  ];

  /// Templates whose categories aren't all taken by existing budgets.
  List<BudgetTemplate> _availableTemplates(List<TxnCategory> categories) => [
    for (final t in BudgetTemplate.all)
      if (_createdBudgets.contains(t.name) || _freeCategories(t, categories).isNotEmpty) t,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final page = switch (_step) {
      0 => _monthStep(context),
      1 => _accountsStep(context),
      _ => _budgetsStep(context),
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                  child: Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        AnimatedContainer(
                          duration: context.motion(const Duration(milliseconds: 250)),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _step ? 28 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: i <= _step ? colors.primary : colors.divider,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Step ${_step + 1} of 3',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ),
                      const Spacer(),
                      TextButton(onPressed: _busy ? null : () => _run(_finish), child: const Text('Skip setup')),
                    ],
                  ),
                ),
                Expanded(
                  child: PageTransitionSwitcher(
                    duration: context.motion(const Duration(milliseconds: 300)),
                    reverse: !_forward,
                    transitionBuilder: (child, primary, secondary) => SharedAxisTransition(
                      animation: primary,
                      secondaryAnimation: secondary,
                      transitionType: SharedAxisTransitionType.horizontal,
                      fillColor: Colors.transparent,
                      child: child,
                    ),
                    child: ListView(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      children: [
                        Text(
                          _titles[_step],
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        ...page,
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(_error!, style: TextStyle(color: colors.danger)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 24, 16),
                  child: Row(
                    children: [
                      if (_step > 0)
                        TextButton.icon(
                          onPressed: _busy ? null : () => _go(_step - 1),
                          icon: const Icon(AppIcons.back),
                          label: const Text('Back'),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _busy ? null : _next,
                        icon: _busy
                            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(_step == 2 ? AppIcons.done : AppIcons.forward),
                        label: Text(_step == 2 ? 'Finish' : 'Next'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _monthStep(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(authControllerProvider).value;
    return [
      Text(
        'Budgets and reports follow your month. If your salary comes on the 25th, start your month on the 25th.',
        style: TextStyle(color: colors.textSecondary),
      ),
      const SizedBox(height: 24),
      DropdownButtonFormField<int>(
        isExpanded: true,
        initialValue: _monthStart,
        decoration: const InputDecoration(labelText: 'Month starts on', prefixIcon: Icon(AppIcons.monthStart)),
        items: [
          for (var day = 1; day <= 28; day++)
            DropdownMenuItem(value: day, child: Text(day == 1 ? '1st (calendar month)' : _ordinal(day))),
        ],
        onChanged: (value) => setState(() => _monthStart = value ?? 1),
      ),
      const SizedBox(height: 16),
      ChatTile(
        leading: IconAvatar(icon: AppIcons.timezone, color: colors.primary, radius: 20),
        title: 'Time zone',
        subtitle: '${user?.timezone ?? 'Asia/Kolkata'} · change it later in Settings',
      ),
    ];
  }

  List<Widget> _accountsStep(BuildContext context) {
    final colors = context.colors;
    final existing = ref.watch(accountsProvider).value?.active ?? const <Account>[];
    if (existing.isNotEmpty) {
      return [
        Text(
          'You already have these accounts. You can add more any time.',
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 12),
        for (final account in existing)
          ChatTile(
            leading: IconAvatar(icon: AppIcons.byKey(account.icon), color: account.color, solid: true),
            title: account.name,
            subtitle: account.type.label,
          ),
      ];
    }
    return [
      Text(
        'Where do you keep money? Enter what each has right now; each account becomes a chat.',
        style: TextStyle(color: colors.textSecondary),
      ),
      const SizedBox(height: 12),
      for (final (type, name, hint) in _starterAccounts) ...[
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _accountOn[type],
          onChanged: (value) => setState(() => _accountOn[type] = value ?? false),
          secondary: IconAvatar(icon: AppIcons.byKey(type.defaultIcon), color: type.defaultColor, solid: true),
          title: Text(name),
          subtitle: Text(type.label),
        ),
        AnimatedSize(
          duration: context.motion(const Duration(milliseconds: 200)),
          child: _accountOn[type]!
              ? Padding(
                  padding: const EdgeInsets.only(left: 56, bottom: 12),
                  child: AmountField(controller: _accountAmount[type]!, hint: hint, required: false),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    ];
  }

  List<Widget> _budgetsStep(BuildContext context) {
    final colors = context.colors;
    final categories = ref.watch(categoriesProvider).value ?? const <TxnCategory>[];
    final templates = _availableTemplates(categories);
    return [
      Text(
        'Pick what you want to keep an eye on. One budget can cover several categories, like bike EMI + petrol.',
        style: TextStyle(color: colors.textSecondary),
      ),
      const SizedBox(height: 12),
      if (templates.isEmpty) Text('Your budgets are already set up.', style: TextStyle(color: colors.textSecondary)),
      for (final template in templates) ...[
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _budgetOn[template.name],
          onChanged: _createdBudgets.contains(template.name)
              ? null
              : (value) => setState(() => _budgetOn[template.name] = value ?? false),
          secondary: IconAvatar(icon: AppIcons.byKey(template.icon), color: colors.primary),
          title: Text(template.name),
          subtitle: Text(template.hint),
        ),
        AnimatedSize(
          duration: context.motion(const Duration(milliseconds: 200)),
          child: _budgetOn[template.name]! && !_createdBudgets.contains(template.name)
              ? Padding(
                  padding: const EdgeInsets.only(left: 56, bottom: 12),
                  child: AmountField(
                    controller: _budgetAmount[template.name]!,
                    hint: 'Monthly amount',
                    allowZero: false,
                    required: false,
                    errorText: _budgetErrors[template.name],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
      const SizedBox(height: 8),
      Text('You can change these, or add more, on the Budgets tab.', style: TextStyle(color: colors.textSecondary)),
    ];
  }

  static String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    return switch (day % 10) {
      1 => '${day}st',
      2 => '${day}nd',
      3 => '${day}rd',
      _ => '${day}th',
    };
  }
}
