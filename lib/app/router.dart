import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/domain/auth_status.dart';
import '../features/auth/presentation/change_password_page.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/set_password_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/duty/presentation/home_page.dart';
import '../features/routes/presentation/day_route_page.dart';
import '../features/routes/presentation/history_page.dart';
import '../features/routes/presentation/live_map_page.dart';
import '../features/routes/presentation/my_map_page.dart';
import '../features/users/presentation/account_button.dart';
import '../features/users/presentation/account_page.dart';
import '../features/users/presentation/user_form_page.dart';
import '../features/users/presentation/users_page.dart';
import '../shared/widgets/coming_soon_page.dart';
import '../shared/widgets/nav_shell.dart';
import 'routes.dart';

/// The app's router. Rebuilt never: it re-checks [resolveRedirect] whenever
/// the auth status changes, so signing in, signing out or a role change moves
/// the user to the right side of the app at once.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<AuthStatus> status = ValueNotifier<AuthStatus>(
    ref.read(authStatusProvider),
  );
  ref.listen<AuthStatus>(
    authStatusProvider,
    (AuthStatus? _, AuthStatus next) => status.value = next,
  );

  // Forms and the admin's account open over the tab bar, on this navigator.
  final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>();

  final GoRouter router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.splash,
    refreshListenable: status,
    redirect: (BuildContext context, GoRouterState state) =>
        resolveRedirect(status.value, state.matchedLocation),
    routes: <RouteBase>[
      GoRoute(
        path: Routes.splash,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashPage(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginPage(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (BuildContext context, GoRouterState state) =>
            const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.setPassword,
        builder: (BuildContext context, GoRouterState state) =>
            const SetPasswordPage(),
      ),
      // Listed before the admin tabs so it is not taken for a tab.
      GoRoute(
        path: Routes.adminAccount,
        builder: (BuildContext context, GoRouterState state) =>
            const AccountPage(
              title: 'My account',
              changePasswordRoute: Routes.adminChangePassword,
            ),
        routes: <RouteBase>[
          GoRoute(
            path: 'password',
            builder: (BuildContext context, GoRouterState state) =>
                const ChangePasswordPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/admin/days/:dayId',
        builder: (BuildContext context, GoRouterState state) =>
            DayRoutePage(dayId: int.parse(state.pathParameters['dayId']!)),
      ),
      _userShell(rootKey),
      _adminShell(rootKey),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    status.dispose();
  });
  return router;
});

GoRoute _tab(
  String path,
  String title,
  String phase,
  IconData icon, {
  bool adminAccount = false,
}) => GoRoute(
  path: path,
  builder: (BuildContext context, GoRouterState state) => ComingSoonPage(
    title: title,
    phase: phase,
    icon: icon,
    actions: adminAccount ? const <Widget>[AccountButton()] : const <Widget>[],
  ),
);

StatefulShellRoute _userShell(
  GlobalKey<NavigatorState> rootKey,
) => StatefulShellRoute.indexedStack(
  builder:
      (BuildContext context, GoRouterState state, StatefulNavigationShell s) =>
          NavShell(
            shell: s,
            tabs: const <NavTab>[
              NavTab(label: 'Home', icon: Icons.home_rounded),
              NavTab(label: 'Map', icon: Icons.map_rounded),
              NavTab(label: 'History', icon: Icons.calendar_month_rounded),
              NavTab(label: 'Profile', icon: Icons.person_rounded),
            ],
          ),
  branches: <StatefulShellBranch>[
    StatefulShellBranch(
      routes: <RouteBase>[
        GoRoute(
          path: Routes.userHome,
          builder: (BuildContext context, GoRouterState state) =>
              const HomePage(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: <RouteBase>[
        GoRoute(
          path: Routes.userMap,
          builder: (BuildContext context, GoRouterState state) =>
              const MyMapPage(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: <RouteBase>[
        GoRoute(
          path: Routes.userHistory,
          builder: (BuildContext context, GoRouterState state) =>
              const HistoryPage(dayRoute: Routes.userDay),
          routes: <RouteBase>[
            GoRoute(
              path: 'day/:dayId',
              parentNavigatorKey: rootKey,
              builder: (BuildContext context, GoRouterState state) =>
                  DayRoutePage(
                    dayId: int.parse(state.pathParameters['dayId']!),
                  ),
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      routes: <RouteBase>[
        GoRoute(
          path: Routes.userProfile,
          builder: (BuildContext context, GoRouterState state) =>
              const AccountPage(changePasswordRoute: Routes.userChangePassword),
          routes: <RouteBase>[
            GoRoute(
              path: 'password',
              parentNavigatorKey: rootKey,
              builder: (BuildContext context, GoRouterState state) =>
                  const ChangePasswordPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);

StatefulShellRoute _adminShell(GlobalKey<NavigatorState> rootKey) =>
    StatefulShellRoute.indexedStack(
      builder:
          (
            BuildContext context,
            GoRouterState state,
            StatefulNavigationShell s,
          ) => NavShell(
            shell: s,
            tabs: const <NavTab>[
              NavTab(label: 'Dashboard', icon: Icons.dashboard_rounded),
              NavTab(label: 'Live', icon: Icons.location_on_rounded),
              NavTab(label: 'Requests', icon: Icons.inbox_rounded),
              NavTab(label: 'Users', icon: Icons.group_rounded),
              NavTab(label: 'Reports', icon: Icons.picture_as_pdf_rounded),
            ],
          ),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            _tab(
              Routes.adminDashboard,
              'Dashboard',
              'phase 6 (requests)',
              Icons.dashboard_rounded,
              adminAccount: true,
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.adminLiveMap,
              builder: (BuildContext context, GoRouterState state) =>
                  const LiveMapPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            _tab(
              Routes.adminRequests,
              'Requests',
              'phase 6 (requests)',
              Icons.inbox_rounded,
              adminAccount: true,
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.adminUsers,
              builder: (BuildContext context, GoRouterState state) =>
                  const UsersPage(),
              routes: <RouteBase>[
                // 'new' before ':id', so it is not read as an id.
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: rootKey,
                  builder: (BuildContext context, GoRouterState state) =>
                      const UserFormPage(),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: rootKey,
                  builder: (BuildContext context, GoRouterState state) =>
                      UserFormPage(userId: state.pathParameters['id']),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'days',
                      parentNavigatorKey: rootKey,
                      builder: (BuildContext context, GoRouterState state) =>
                          HistoryPage(
                            userId: state.pathParameters['id'],
                            title: 'Duty history',
                            dayRoute: Routes.adminDay,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            _tab(
              Routes.adminReports,
              'Reports',
              'phase 8 (reports)',
              Icons.picture_as_pdf_rounded,
              adminAccount: true,
            ),
          ],
        ),
      ],
    );
