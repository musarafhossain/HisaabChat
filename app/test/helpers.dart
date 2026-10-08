import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/app/app.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/storage/preferences.dart';
import 'package:hisaabchat/core/storage/token_store.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/accounts/data/accounts_repository.dart';
import 'package:hisaabchat/features/auth/data/app_user.dart';
import 'package:hisaabchat/features/auth/data/auth_repository.dart';
import 'package:hisaabchat/features/budgets/data/budget.dart';
import 'package:hisaabchat/features/budgets/data/budgets_repository.dart';
import 'package:hisaabchat/features/categories/data/categories_repository.dart';
import 'package:hisaabchat/features/categories/data/category.dart';
import 'package:hisaabchat/features/reports/data/report.dart';
import 'package:hisaabchat/features/reports/data/reports_repository.dart';
import 'package:hisaabchat/features/transactions/data/transactions_repository.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:shared_preferences/shared_preferences.dart';

const testUser = AppUser(
  id: '0192f1d2-7c1a-7b3e-9a1e-2f6c1d0a9b11',
  email: 'asha@example.com',
  fullName: 'Asha Rao',
  initials: 'AR',
  currency: 'INR',
  timezone: 'Asia/Kolkata',
  monthStartDay: 1,
  theme: ThemeMode.light,
);

/// [user] with some fields replaced (the fakes' stand-in for PATCH /me).
AppUser copyUser(AppUser user, {int? monthStartDay, DateTime? onboardedAt}) => AppUser(
  id: user.id,
  email: user.email,
  fullName: user.fullName,
  initials: user.initials,
  currency: user.currency,
  timezone: user.timezone,
  monthStartDay: monthStartDay ?? user.monthStartDay,
  theme: user.theme,
  onboardedAt: onboardedAt ?? user.onboardedAt,
);

/// In-memory stand-in for the auth endpoints.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.meError, bool onboarded = true})
    : user = onboarded ? copyUser(testUser, onboardedAt: DateTime.utc(2026)) : testUser;

  /// The signed-in user as the server sees them.
  AppUser user;

  /// Thrown by [me] (e.g. a 401 for an expired token).
  ApiException? meError;
  int logoutCalls = 0;
  Map<String, Object?>? lastProfileUpdate;

  static const _password = 'secret-password';

  @override
  Future<AuthSession> login({required String email, required String password, required String deviceName}) async {
    if (email != testUser.email || password != _password) {
      throw const ApiException(message: 'Invalid user credentials', statusCode: 400);
    }
    return (user: user, token: 'oat_test');
  }

  @override
  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
    required String deviceName,
    String? timezone,
  }) async {
    if (email == testUser.email) {
      throw const ApiException(
        message: 'The email has already been taken',
        statusCode: 422,
        fieldErrors: {'email': 'The email has already been taken'},
      );
    }
    user = AppUser(
      id: 'new-user',
      email: email,
      fullName: fullName,
      initials: 'NU',
      currency: 'INR',
      timezone: timezone ?? 'Asia/Kolkata',
      monthStartDay: 1,
      theme: ThemeMode.system,
    );
    return (
      user: AppUser(
        id: 'new-user',
        email: email,
        fullName: fullName,
        initials: 'NU',
        currency: 'INR',
        timezone: timezone ?? 'Asia/Kolkata',
        monthStartDay: 1,
        theme: ThemeMode.system,
      ),
      token: 'oat_new',
    );
  }

  @override
  Future<AppUser> me() async {
    if (meError != null) throw meError!;
    return user;
  }

  @override
  Future<AppUser> updateProfile(Map<String, Object?> changes) async {
    lastProfileUpdate = changes;
    return user = copyUser(user, monthStartDay: changes['monthStartDay'] as int?);
  }

  int onboardingCompletions = 0;

  @override
  Future<AppUser> completeOnboarding() async {
    onboardingCompletions++;
    return user = copyUser(user, onboardedAt: DateTime.now().toUtc());
  }

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  Future<void> logoutAll() async => logoutCalls++;
}

/// In-memory /accounts API with the same rules as the server.
class FakeAccountsRepository implements AccountsRepository {
  FakeAccountsRepository([List<Account>? seed]) : accounts = [...?seed];

  final List<Account> accounts;

  /// Ids that have transactions (delete → 409).
  final Set<String> usedIds = {};
  int _next = 0;

  @override
  Future<AccountsPage> list() async {
    final netWorth = accounts.where((a) => !a.archived && a.includeInTotal).fold<int>(0, (sum, a) => sum + a.balance);
    return (accounts: List<Account>.of(accounts), netWorth: netWorth);
  }

  @override
  Future<Account> create(Map<String, Object?> body) async {
    final name = body['name']! as String;
    if (accounts.any((a) => a.name.toLowerCase() == name.toLowerCase())) {
      throw const ApiException(
        message: 'Validation failed',
        statusCode: 422,
        fieldErrors: {'name': 'You already have an account with this name'},
      );
    }
    final type = AccountType.fromApi(body['type']! as String);
    final opening = (body['openingBalance'] as int?) ?? 0;
    final account = Account(
      id: 'acc-${_next++}',
      name: name,
      type: type,
      openingBalance: opening,
      balance: opening,
      creditLimit: type == AccountType.creditCard ? body['creditLimit'] as int? : null,
      color: parseHexColor((body['color'] as String?) ?? '#16A34A'),
      icon: (body['icon'] as String?) ?? type.defaultIcon,
      includeInTotal: (body['includeInTotal'] as bool?) ?? true,
      archived: false,
    );
    accounts.add(account);
    return account;
  }

  @override
  Future<Account> update(String id, Map<String, Object?> changes) async {
    final index = accounts.indexWhere((a) => a.id == id);
    final old = accounts[index];
    final opening = (changes['openingBalance'] as int?) ?? old.openingBalance;
    final type = changes['type'] == null ? old.type : AccountType.fromApi(changes['type']! as String);
    final updated = Account(
      id: old.id,
      name: (changes['name'] as String?) ?? old.name,
      type: type,
      openingBalance: opening,
      balance: old.balance + (opening - old.openingBalance),
      creditLimit: type == AccountType.creditCard ? changes['creditLimit'] as int? : null,
      color: changes['color'] == null ? old.color : parseHexColor(changes['color']! as String),
      icon: (changes['icon'] as String?) ?? old.icon,
      includeInTotal: (changes['includeInTotal'] as bool?) ?? old.includeInTotal,
      archived: old.archived,
    );
    accounts[index] = updated;
    return updated;
  }

  @override
  Future<Account> setArchived(String id, {required bool archived}) async {
    final index = accounts.indexWhere((a) => a.id == id);
    final old = accounts[index];
    return accounts[index] = Account(
      id: old.id,
      name: old.name,
      type: old.type,
      openingBalance: old.openingBalance,
      balance: old.balance,
      creditLimit: old.creditLimit,
      color: old.color,
      icon: old.icon,
      includeInTotal: old.includeInTotal,
      archived: archived,
    );
  }

  /// Moves a balance (used by [FakeTransactionsRepository]).
  void applyDelta(String id, int delta) {
    final index = accounts.indexWhere((a) => a.id == id);
    final old = accounts[index];
    accounts[index] = Account(
      id: old.id,
      name: old.name,
      type: old.type,
      openingBalance: old.openingBalance,
      balance: old.balance + delta,
      creditLimit: old.creditLimit,
      color: old.color,
      icon: old.icon,
      includeInTotal: old.includeInTotal,
      archived: old.archived,
    );
  }

  Account byId(String id) => accounts.firstWhere((a) => a.id == id);

  @override
  Future<void> delete(String id) async {
    if (usedIds.contains(id)) {
      throw const ApiException(message: 'This account has transactions. Archive it instead.', statusCode: 409);
    }
    accounts.removeWhere((a) => a.id == id);
  }
}

/// Default categories (subset of the server's seed).
List<TxnCategory> defaultCategories() {
  var order = 0;
  TxnCategory cat(String name, String icon, CategoryType type) => TxnCategory(
    id: 'cat-${name.toLowerCase().replaceAll(RegExp('[^a-z]+'), '-')}',
    name: name,
    type: type,
    color: const Color(0xFF10B981),
    icon: icon,
    sortOrder: order++,
    isDefault: true,
  );
  return [
    cat('Room Rent', 'home', CategoryType.expense),
    cat('Food & Groceries', 'shopping_cart', CategoryType.expense),
    cat('Eating Out', 'restaurant', CategoryType.expense),
    cat('Bike EMI', 'two_wheeler', CategoryType.expense),
    cat('Petrol', 'local_gas_station', CategoryType.expense),
    cat('Education', 'school', CategoryType.expense),
    cat('Salary', 'work', CategoryType.income),
    cat('Refund', 'undo', CategoryType.income),
  ];
}

class FakeCategoriesRepository implements CategoriesRepository {
  FakeCategoriesRepository([List<TxnCategory>? seed]) : categories = seed ?? defaultCategories();

  final List<TxnCategory> categories;

  TxnCategory byName(String name) => categories.firstWhere((c) => c.name == name);

  /// Sets or clears a category's budget link (like categories.budget_id).
  void link(String id, String? budgetId) {
    final index = categories.indexWhere((c) => c.id == id);
    final old = categories[index];
    categories[index] = TxnCategory(
      id: old.id,
      name: old.name,
      type: old.type,
      color: old.color,
      icon: old.icon,
      sortOrder: old.sortOrder,
      isDefault: old.isDefault,
      archived: old.archived,
      parentId: old.parentId,
      budgetId: budgetId,
    );
  }

  @override
  Future<List<TxnCategory>> list() async => List.of(categories);

  @override
  Future<TxnCategory> create(Map<String, Object?> body) async {
    final category = TxnCategory(
      id: 'cat-new-${categories.length}',
      name: body['name']! as String,
      type: CategoryType.fromApi(body['type']! as String),
      color: parseHexColor(body['color']! as String),
      icon: body['icon']! as String,
      sortOrder: categories.length,
    );
    categories.add(category);
    return category;
  }

  @override
  Future<TxnCategory> update(String id, Map<String, Object?> changes) async {
    final index = categories.indexWhere((c) => c.id == id);
    final old = categories[index];
    return categories[index] = TxnCategory(
      id: old.id,
      name: (changes['name'] as String?) ?? old.name,
      type: old.type,
      color: changes['color'] == null ? old.color : parseHexColor(changes['color']! as String),
      icon: (changes['icon'] as String?) ?? old.icon,
      sortOrder: old.sortOrder,
    );
  }

  @override
  Future<TxnCategory> setArchived(String id, {required bool archived}) async {
    final index = categories.indexWhere((c) => c.id == id);
    final old = categories[index];
    return categories[index] = TxnCategory(
      id: old.id,
      name: old.name,
      type: old.type,
      color: old.color,
      icon: old.icon,
      sortOrder: old.sortOrder,
      archived: archived,
    );
  }
}

/// In-memory `/transactions` that moves the fake account balances like the server.
class FakeTransactionsRepository implements TransactionsRepository {
  FakeTransactionsRepository(this.accounts, this.categories);

  final FakeAccountsRepository accounts;
  final FakeCategoriesRepository categories;
  final List<Txn> txns = [];

  /// Number of upcoming create calls that fail with a network error.
  int failNextCreates = 0;

  /// Set by pumpApp so creates can report budget alerts.
  FakeBudgetsRepository? budgets;

  AccountRef _accountRef(String id) {
    final a = accounts.byId(id);
    return AccountRef(id: a.id, name: a.name, icon: a.icon, color: a.color);
  }

  Txn _build(String id, Map<String, Object?> body) {
    final type = TxnType.fromApi(body['type']! as String);
    final categoryId = body['categoryId'] as String?;
    final category = categoryId == null ? null : categories.categories.firstWhere((c) => c.id == categoryId);
    return Txn(
      id: id,
      type: type,
      amount: body['amount']! as int,
      date: DateTime.parse(body['date']! as String).toUtc(),
      note: body['note'] as String?,
      account: _accountRef(body['accountId']! as String),
      toAccount: body['toAccountId'] == null ? null : _accountRef(body['toAccountId']! as String),
      category: category == null
          ? null
          : CategoryRef(id: category.id, name: category.name, icon: category.icon, color: category.color),
      adjustmentIncrease: body['adjustmentIncrease'] as bool?,
    );
  }

  void _apply(Txn t, int sign) {
    switch (t.type) {
      case TxnType.income:
        accounts.applyDelta(t.account.id, sign * t.amount);
      case TxnType.expense:
        accounts.applyDelta(t.account.id, -sign * t.amount);
      case TxnType.transfer:
        accounts
          ..applyDelta(t.account.id, -sign * t.amount)
          ..applyDelta(t.toAccount!.id, sign * t.amount);
      case TxnType.adjustment:
        accounts.applyDelta(t.account.id, sign * (t.adjustmentIncrease! ? t.amount : -t.amount));
    }
  }

  @override
  Future<TxnPage> list(TxnQuery query, {String? cursor, int limit = 30}) async {
    final q = query.q?.toLowerCase() ?? '';
    final items =
        txns
            .where(
              (t) =>
                  (query.accountId == null || t.account.id == query.accountId || t.toAccount?.id == query.accountId) &&
                  (query.type == null || t.type == query.type) &&
                  (query.categoryId == null || t.category?.id == query.categoryId) &&
                  (query.from == null || !t.date.isBefore(query.from!)) &&
                  (query.to == null || t.date.isBefore(query.to!)) &&
                  (q.isEmpty ||
                      (t.note ?? '').toLowerCase().contains(q) ||
                      (t.category?.name ?? '').toLowerCase().contains(q)),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final income = items.where((t) => t.type == TxnType.income).fold<int>(0, (s, t) => s + t.amount);
    final expense = items.where((t) => t.type == TxnType.expense).fold<int>(0, (s, t) => s + t.amount);
    return (
      items: items,
      nextCursor: null,
      totals: TxnTotals(income: income, expense: expense, count: items.length),
    );
  }

  @override
  Future<TxnSaved> create(Map<String, Object?> body) async {
    if (failNextCreates > 0) {
      failNextCreates--;
      throw const ApiException(message: 'Waiting for network…', isNetworkError: true);
    }
    final id = (body['id'] as String?) ?? 'txn-${txns.length}';
    final existing = txns.where((t) => t.id == id);
    if (existing.isNotEmpty) return (txn: existing.first, alerts: const <BudgetAlert>[]);
    final txn = _build(id, body);
    txns.add(txn);
    _apply(txn, 1);
    return (txn: txn, alerts: budgets?.alertsFor(txn) ?? const <BudgetAlert>[]);
  }

  @override
  Future<Txn> update(String id, Map<String, Object?> changes) async {
    final index = txns.indexWhere((t) => t.id == id);
    final old = txns[index];
    _apply(old, -1);
    final merged = {...old.toCreateBody(), ...changes};
    final updated = _build(id, merged);
    txns[index] = updated;
    _apply(updated, 1);
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    final index = txns.indexWhere((t) => t.id == id);
    _apply(txns.removeAt(index), -1);
  }

  @override
  Future<Txn?> reconcile(String accountId, int actualBalance) async {
    final diff = actualBalance - accounts.byId(accountId).balance;
    if (diff == 0) return null;
    final txn = _build('adj-${txns.length}', {
      'type': 'ADJUSTMENT',
      'amount': diff.abs(),
      'accountId': accountId,
      'date': DateTime.now().toUtc().toIso8601String(),
      'note': 'Balance adjusted',
      'adjustmentIncrease': diff > 0,
    });
    txns.add(txn);
    _apply(txn, 1);
    return txn;
  }
}

class FakeBudget {
  FakeBudget({
    required this.id,
    required this.name,
    required this.amount,
    required this.kind,
    required this.alertPercent,
    required this.color,
    required this.icon,
  });

  final String id;
  String name;
  int amount;
  BudgetKind kind;
  int alertPercent;
  Color color;
  String icon;
  final Map<String, int> overrides = {};
}

/// In-memory `/budgets` for the current calendar month, computed from the
/// fake transactions like the server does.
class FakeBudgetsRepository implements BudgetsRepository {
  FakeBudgetsRepository(this.txns, this.categories);

  final FakeTransactionsRepository txns;
  final FakeCategoriesRepository categories;
  final List<FakeBudget> budgets = [];

  static String get currentMonth {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  List<String> _categoryIds(String budgetId) => [
    for (final c in categories.categories)
      if (c.budgetId == budgetId) c.id,
  ];

  int _spent(String budgetId, String month) {
    final ids = _categoryIds(budgetId);
    return txns.txns
        .where(
          (t) =>
              t.type == TxnType.expense &&
              ids.contains(t.category?.id) &&
              '${t.localDate.year}-${t.localDate.month.toString().padLeft(2, '0')}' == month,
        )
        .fold<int>(0, (sum, t) => sum + t.amount);
  }

  BudgetStatus _status(FakeBudget b, String month) {
    final budgeted = b.overrides[month] ?? b.amount;
    final spent = _spent(b.id, month);
    final percent = budgeted > 0 ? (spent * 100 / budgeted).round() : 0;
    final now = DateTime.now();
    final daysLeft = DateTime(now.year, now.month + 1, 0).day - now.day + 1;
    return BudgetStatus(
      id: b.id,
      name: b.name,
      kind: b.kind,
      color: b.color,
      icon: b.icon,
      alertPercent: b.alertPercent,
      categories: [
        for (final c in categories.categories)
          if (c.budgetId == b.id) CategoryRef(id: c.id, name: c.name, icon: c.icon, color: c.color),
      ],
      amount: b.amount,
      budgeted: budgeted,
      hasOverride: b.overrides.containsKey(month),
      spent: spent,
      remaining: budgeted - spent,
      percent: percent,
      state: spent > budgeted
          ? BudgetState.exceeded
          : percent >= b.alertPercent
          ? BudgetState.warning
          : BudgetState.ok,
      daysLeft: daysLeft,
      safeToSpendPerDay: b.kind == BudgetKind.variable ? ((budgeted - spent).clamp(0, 1 << 52) ~/ daysLeft) : null,
    );
  }

  List<BudgetAlert> alertsFor(Txn txn) {
    if (txn.type != TxnType.expense) return const [];
    final categoryId = txn.category?.id;
    final link = categories.categories.where((c) => c.id == categoryId).firstOrNull?.budgetId;
    final budget = budgets.where((b) => b.id == link).firstOrNull;
    if (budget == null) return const [];
    final month = currentMonth;
    final budgeted = budget.overrides[month] ?? budget.amount;
    final after = _spent(budget.id, month);
    final before = after - txn.amount;
    final crossedLimit = before <= budgeted && after > budgeted;
    final crossedAlert = before * 100 / budgeted < budget.alertPercent && after * 100 / budgeted >= budget.alertPercent;
    if (!crossedLimit && !crossedAlert) return const [];
    return [
      BudgetAlert(
        budgetId: budget.id,
        name: budget.name,
        percent: (after * 100 / budgeted).round(),
        exceeded: crossedLimit,
        remaining: budgeted - after,
      ),
    ];
  }

  @override
  Future<BudgetsOverview> overview({String? month}) async {
    final m = month ?? currentMonth;
    final statuses = [for (final b in budgets) _status(b, m)];
    final parts = m.split('-').map(int.parse).toList();
    final inBudgets = {for (final b in budgets) ..._categoryIds(b.id)};
    final unbudgeted = txns.txns
        .where(
          (t) =>
              t.type == TxnType.expense &&
              !inBudgets.contains(t.category?.id) &&
              '${t.localDate.year}-${t.localDate.month.toString().padLeft(2, '0')}' == m,
        )
        .fold<int>(0, (sum, t) => sum + t.amount);
    return BudgetsOverview(
      month: m,
      periodStart: DateTime(parts[0], parts[1]),
      periodEnd: DateTime(parts[0], parts[1] + 1, 0),
      daysLeft: statuses.isEmpty ? 1 : statuses.first.daysLeft,
      budgets: statuses,
      budgeted: statuses.fold(0, (sum, s) => sum + s.budgeted),
      spent: statuses.fold(0, (sum, s) => sum + s.spent),
      unbudgeted: unbudgeted,
    );
  }

  @override
  Future<BudgetDetail> detail(String id, {String? month}) async {
    final m = month ?? currentMonth;
    final budget = budgets.firstWhere(
      (b) => b.id == id,
      orElse: () => throw const ApiException(message: 'Budget not found', statusCode: 404),
    );
    final ids = _categoryIds(id);
    final parts = m.split('-').map(int.parse).toList();
    return BudgetDetail(
      status: _status(budget, m),
      transactions: txns.txns.where((t) => t.type == TxnType.expense && ids.contains(t.category?.id)).toList()
        ..sort((a, b) => b.date.compareTo(a.date)),
      history: [
        for (var i = 5; i > 0; i--) BudgetHistoryPoint(month: _shift(m, -i), spent: 0),
        BudgetHistoryPoint(month: m, spent: _spent(id, m), budgeted: budget.overrides[m] ?? budget.amount),
      ],
      periodStart: DateTime(parts[0], parts[1]),
      periodEnd: DateTime(parts[0], parts[1] + 1, 0),
    );
  }

  static String _shift(String month, int by) {
    final parts = month.split('-').map(int.parse).toList();
    final d = DateTime(parts[0], parts[1] + by);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  void _assertCategories(List<String> ids, {String? budgetId}) {
    for (final id in ids) {
      final category = categories.categories.firstWhere((c) => c.id == id);
      if (category.budgetId != null && category.budgetId != budgetId) {
        final other = budgets.firstWhere((b) => b.id == category.budgetId).name;
        throw ApiException(
          message: 'Validation failed',
          statusCode: 422,
          fieldErrors: {'categoryIds': '${category.name} is already in the “$other” budget'},
        );
      }
    }
  }

  @override
  Future<void> create(Map<String, Object?> body) async {
    final ids = (body['categoryIds']! as List).cast<String>();
    _assertCategories(ids);
    final budget = FakeBudget(
      id: 'budget-${budgets.length}',
      name: body['name']! as String,
      amount: body['amount']! as int,
      kind: BudgetKind.fromApi((body['kind'] as String?) ?? 'VARIABLE'),
      alertPercent: (body['alertPercent'] as int?) ?? 80,
      color: parseHexColor((body['color'] as String?) ?? '#16A34A'),
      icon: (body['icon'] as String?) ?? 'savings',
    );
    budgets.add(budget);
    for (final id in ids) {
      categories.link(id, budget.id);
    }
  }

  @override
  Future<void> update(String id, Map<String, Object?> changes) async {
    final budget = budgets.firstWhere((b) => b.id == id);
    if (changes['name'] != null) budget.name = changes['name']! as String;
    if (changes['amount'] != null) budget.amount = changes['amount']! as int;
    if (changes['kind'] != null) budget.kind = BudgetKind.fromApi(changes['kind']! as String);
    if (changes['alertPercent'] != null) budget.alertPercent = changes['alertPercent']! as int;
    final ids = (changes['categoryIds'] as List?)?.cast<String>();
    if (ids != null) {
      _assertCategories(ids, budgetId: id);
      for (final c in List.of(categories.categories)) {
        if (c.budgetId == id && !ids.contains(c.id)) categories.link(c.id, null);
      }
      for (final cid in ids) {
        categories.link(cid, id);
      }
    }
  }

  @override
  Future<void> archive(String id) async {
    budgets.removeWhere((b) => b.id == id);
    for (final c in List.of(categories.categories)) {
      if (c.budgetId == id) categories.link(c.id, null);
    }
  }

  @override
  Future<void> setOverride(String id, String month, int amount) async =>
      budgets.firstWhere((b) => b.id == id).overrides[month] = amount;

  @override
  Future<void> deleteOverride(String id, String month) async =>
      budgets.firstWhere((b) => b.id == id).overrides.remove(month);
}

/// `/dashboard` and `/reports` for the current calendar month, computed
/// from the fake accounts, transactions and budgets.
class FakeReportsRepository implements ReportsRepository {
  FakeReportsRepository(this.accounts, this.txns, this.budgets);

  final FakeAccountsRepository accounts;
  final FakeTransactionsRepository txns;
  final FakeBudgetsRepository budgets;

  /// Thrown by every call when set (e.g. a network error).
  ApiException? error;

  static String _monthOf(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';

  (DateTime, DateTime) _bounds(String month) {
    final parts = month.split('-').map(int.parse).toList();
    return (DateTime(parts[0], parts[1]), DateTime(parts[0], parts[1] + 1));
  }

  Iterable<Txn> _in(String month) => txns.txns.where((t) => _monthOf(t.localDate) == month);

  int _sum(String month, TxnType type) =>
      _in(month).where((t) => t.type == type).fold<int>(0, (sum, t) => sum + t.amount);

  @override
  Future<Dashboard> dashboard({String? month}) async {
    if (error != null) throw error!;
    final m = month ?? FakeBudgetsRepository.currentMonth;
    final (start, end) = _bounds(m);
    final overview = await budgets.overview(month: m);
    final page = await accounts.list();
    final active = page.accounts.where((a) => !a.archived);
    final recent = [...txns.txns]..sort((a, b) => b.date.compareTo(a.date));
    return Dashboard(
      month: m,
      periodStart: start,
      periodEnd: end.subtract(const Duration(days: 1)),
      netWorth: active.fold<int>(0, (sum, a) => sum + a.balance),
      accountsCount: active.length,
      income: _sum(m, TxnType.income),
      expense: _sum(m, TxnType.expense),
      budgets: overview.budgets,
      budgeted: overview.budgeted,
      spent: overview.spent,
      recent: recent.take(8).toList(),
    );
  }

  @override
  Future<CategoryReport> byCategory({required TxnType type, String? month}) async {
    if (error != null) throw error!;
    final m = month ?? FakeBudgetsRepository.currentMonth;
    final (start, end) = _bounds(m);
    final byId = <String, List<Txn>>{};
    for (final t in _in(m).where((t) => t.type == type && t.category != null)) {
      (byId[t.category!.id] ??= []).add(t);
    }
    final total = byId.values.expand((l) => l).fold<int>(0, (sum, t) => sum + t.amount);
    final items = [
      for (final entry in byId.entries)
        CategorySpend(
          categoryId: entry.key,
          name: entry.value.first.category!.name,
          icon: entry.value.first.category!.icon,
          color: entry.value.first.category!.color,
          total: entry.value.fold<int>(0, (sum, t) => sum + t.amount),
          count: entry.value.length,
          percent: 0,
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return CategoryReport(
      month: m,
      periodStart: start,
      periodEnd: end.subtract(const Duration(days: 1)),
      from: start.toUtc(),
      to: end.toUtc(),
      type: type,
      total: total,
      items: [
        for (final i in items)
          CategorySpend(
            categoryId: i.categoryId,
            name: i.name,
            icon: i.icon,
            color: i.color,
            total: i.total,
            count: i.count,
            percent: total > 0 ? (i.total * 1000 / total).round() / 10 : 0,
          ),
      ],
    );
  }

  @override
  Future<List<TrendPoint>> trend({int months = 6, String? month}) async {
    if (error != null) throw error!;
    final parts = (month ?? FakeBudgetsRepository.currentMonth).split('-').map(int.parse).toList();
    return [
      for (var i = months - 1; i >= 0; i--)
        () {
          final m = _monthOf(DateTime(parts[0], parts[1] - i));
          return TrendPoint(month: m, income: _sum(m, TxnType.income), expense: _sum(m, TxnType.expense));
        }(),
    ];
  }
}

/// Pumps the whole app with fakes and a fixed window size.
typedef TestApp = ({
  FakeAuthRepository repo,
  MemoryTokenStore tokens,
  FakeAccountsRepository accounts,
  FakeCategoriesRepository categories,
  FakeTransactionsRepository txns,
  FakeBudgetsRepository budgets,
  FakeReportsRepository reports,
});

Future<TestApp> pumpApp(
  WidgetTester tester, {
  String? savedToken,
  FakeAuthRepository? repo,
  FakeAccountsRepository? accounts,
  FakeCategoriesRepository? categories,
  Size size = const Size(400, 860),

  /// Adds data (transactions, budgets…) before the app first loads.
  Future<void> Function(TestApp app)? seed,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fakeRepo = repo ?? FakeAuthRepository();
  final tokens = MemoryTokenStore(savedToken);
  final fakeAccounts = accounts ?? FakeAccountsRepository();
  final fakeCategories = categories ?? FakeCategoriesRepository();
  final fakeTxns = FakeTransactionsRepository(fakeAccounts, fakeCategories);
  final fakeBudgets = FakeBudgetsRepository(fakeTxns, fakeCategories);
  fakeTxns.budgets = fakeBudgets;
  final fakeReports = FakeReportsRepository(fakeAccounts, fakeTxns, fakeBudgets);
  final app = (
    repo: fakeRepo,
    tokens: tokens,
    accounts: fakeAccounts,
    categories: fakeCategories,
    txns: fakeTxns,
    budgets: fakeBudgets,
    reports: fakeReports,
  );
  await seed?.call(app);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(fakeRepo),
        accountsRepositoryProvider.overrideWithValue(fakeAccounts),
        categoriesRepositoryProvider.overrideWithValue(fakeCategories),
        transactionsRepositoryProvider.overrideWithValue(fakeTxns),
        budgetsRepositoryProvider.overrideWithValue(fakeBudgets),
        reportsRepositoryProvider.overrideWithValue(fakeReports),
      ],
      child: const HisaabChatApp(),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}
