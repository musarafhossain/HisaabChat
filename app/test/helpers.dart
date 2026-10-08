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
import 'package:hisaabchat/features/categories/data/categories_repository.dart';
import 'package:hisaabchat/features/categories/data/category.dart';
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

/// In-memory stand-in for the auth endpoints.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.meError});

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
    return (user: testUser, token: 'oat_test');
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
    return testUser;
  }

  @override
  Future<AppUser> updateProfile(Map<String, Object?> changes) async {
    lastProfileUpdate = changes;
    return testUser;
  }

  @override
  Future<AppUser> completeOnboarding() async => testUser;

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
  Future<Txn> create(Map<String, Object?> body) async {
    if (failNextCreates > 0) {
      failNextCreates--;
      throw const ApiException(message: 'Waiting for network…', isNetworkError: true);
    }
    final id = (body['id'] as String?) ?? 'txn-${txns.length}';
    final existing = txns.where((t) => t.id == id);
    if (existing.isNotEmpty) return existing.first;
    final txn = _build(id, body);
    txns.add(txn);
    _apply(txn, 1);
    return txn;
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

/// Pumps the whole app with fakes and a fixed window size.
typedef TestApp = ({
  FakeAuthRepository repo,
  MemoryTokenStore tokens,
  FakeAccountsRepository accounts,
  FakeCategoriesRepository categories,
  FakeTransactionsRepository txns,
});

Future<TestApp> pumpApp(
  WidgetTester tester, {
  String? savedToken,
  FakeAuthRepository? repo,
  FakeAccountsRepository? accounts,
  FakeCategoriesRepository? categories,
  Size size = const Size(400, 860),
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

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(fakeRepo),
        accountsRepositoryProvider.overrideWithValue(fakeAccounts),
        categoriesRepositoryProvider.overrideWithValue(fakeCategories),
        transactionsRepositoryProvider.overrideWithValue(fakeTxns),
      ],
      child: const HisaabChatApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (repo: fakeRepo, tokens: tokens, accounts: fakeAccounts, categories: fakeCategories, txns: fakeTxns);
}
