import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/core/motion/page_transitions.dart';
import 'package:hisaabchat/features/accounts/presentation/account_info.dart';
import 'package:hisaabchat/features/accounts/presentation/accounts_section.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/auth/presentation/login_screen.dart';
import 'package:hisaabchat/features/auth/presentation/register_screen.dart';
import 'package:hisaabchat/features/auth/presentation/splash_screen.dart';
import 'package:hisaabchat/features/auth/presentation/welcome_screen.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_info.dart';
import 'package:hisaabchat/features/budgets/presentation/budgets_section.dart';
import 'package:hisaabchat/features/categories/presentation/categories_screen.dart';
import 'package:hisaabchat/features/health/connection_check_screen.dart';
import 'package:hisaabchat/features/home/home_screen.dart';
import 'package:hisaabchat/features/onboarding/onboarding_screen.dart';
import 'package:hisaabchat/features/reports/presentation/category_transactions.dart';
import 'package:hisaabchat/features/reports/presentation/reports_section.dart';
import 'package:hisaabchat/features/settings/appearance_screen.dart';
import 'package:hisaabchat/features/settings/profile_screen.dart';
import 'package:hisaabchat/features/settings/settings_screen.dart';
import 'package:hisaabchat/features/shell/app_shell.dart';
import 'package:hisaabchat/features/shell/destinations.dart';
import 'package:hisaabchat/features/transactions/presentation/account_thread.dart';
import 'package:hisaabchat/features/transactions/presentation/transactions_section.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

const _publicPaths = {'/welcome', '/login', '/register'};

/// Routes from docs/03-AppFlow.md. Signed-out users only see the public
/// screens; signed-in users never see them.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(authControllerProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  GoRoute section(Destination destination, Widget child, {List<RouteBase> routes = const []}) => GoRoute(
    path: destination.path,
    pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: child),
    routes: routes,
  );

  GoRoute fullScreen(String path, Widget child) => GoRoute(
    path: path,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) => sharedAxisPage(key: state.pageKey, child: child),
  );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Destination.home.path,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (auth.isLoading || auth.hasError) return location == '/splash' ? null : '/splash';

      final user = auth.value;
      if (user == null) return _publicPaths.contains(location) ? null : '/welcome';

      // New users set up their month, accounts and budgets first.
      if (user.onboardedAt == null) return location == '/onboarding' ? null : '/onboarding';
      if (_publicPaths.contains(location) || location == '/splash' || location == '/onboarding') {
        return Destination.home.path;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => fadeThroughPage(key: state.pageKey, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => fadeThroughPage(key: state.pageKey, child: const WelcomeScreen()),
      ),
      fullScreen('/login', const LoginScreen()),
      fullScreen('/register', const RegisterScreen()),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => fadeThroughPage(key: state.pageKey, child: const OnboardingScreen()),
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => shell,
        navigatorContainerBuilder: (context, shell, children) => AppShell(shell: shell, children: children),
        branches: [
          StatefulShellBranch(routes: [section(Destination.home, const HomeScreen())]),
          StatefulShellBranch(routes: [section(Destination.transactions, const TransactionsSection())]),
          StatefulShellBranch(
            routes: [
              section(
                Destination.budgets,
                const BudgetsSection(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => sharedAxisPage(
                      key: state.pageKey,
                      child: BudgetInfoScreen(
                        budgetId: state.pathParameters['id']!,
                        month: state.uri.queryParameters['month'],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              section(
                Destination.accounts,
                const AccountsSection(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => sharedAxisPage(
                      key: state.pageKey,
                      child: AccountThreadScreen(accountId: state.pathParameters['id']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'info',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => sharedAxisPage(
                          key: state.pageKey,
                          child: AccountInfoScreen(accountId: state.pathParameters['id']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              section(
                Destination.reports,
                const ReportsSection(),
                routes: [
                  GoRoute(
                    path: 'category/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final query = state.uri.queryParameters;
                      return sharedAxisPage(
                        key: state.pageKey,
                        child: CategoryTransactionsScreen(
                          categoryId: state.pathParameters['id']!,
                          name: query['name'] ?? 'Category',
                          from: DateTime.parse(query['from']!),
                          to: DateTime.parse(query['to']!),
                          period: query['period'] ?? '',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              section(
                Destination.settings,
                const SettingsScreen(),
                routes: [
                  fullScreen('profile', const ProfileScreen()),
                  fullScreen('appearance', const AppearanceScreen()),
                  fullScreen('categories', const CategoriesScreen()),
                  fullScreen('connection', const ConnectionCheckScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
