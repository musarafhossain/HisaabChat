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

  @override
  Future<void> delete(String id) async {
    if (usedIds.contains(id)) {
      throw const ApiException(message: 'This account has transactions. Archive it instead.', statusCode: 409);
    }
    accounts.removeWhere((a) => a.id == id);
  }
}

/// Pumps the whole app with fakes and a fixed window size.
Future<({FakeAuthRepository repo, MemoryTokenStore tokens, FakeAccountsRepository accounts})> pumpApp(
  WidgetTester tester, {
  String? savedToken,
  FakeAuthRepository? repo,
  FakeAccountsRepository? accounts,
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

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(fakeRepo),
        accountsRepositoryProvider.overrideWithValue(fakeAccounts),
      ],
      child: const HisaabChatApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (repo: fakeRepo, tokens: tokens, accounts: fakeAccounts);
}
