import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/ds_icons.dart';
import '../features/admin/presentation/admin_dashboard_page.dart';
import '../features/admin/presentation/admin_nav_shell.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/domain/auth_status.dart';
import '../features/auth/presentation/change_password_page.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/set_password_page.dart';
import '../features/auth/presentation/signed_out_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/duty/presentation/home_page.dart';
import '../features/notifications/presentation/my_notifications_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/requests/presentation/admin_requests_page.dart';
import '../features/requests/presentation/attendance_request_page.dart';
import '../features/requests/presentation/leave_request_page.dart';
import '../features/requests/presentation/my_request_detail_page.dart';
import '../features/requests/presentation/my_requests_page.dart';
import '../features/requests/presentation/request_detail_page.dart';
import '../features/routes/presentation/day_route_page.dart';
import '../features/routes/presentation/history_page.dart';
import '../features/routes/presentation/live_map_page.dart';
import '../features/routes/presentation/my_map_page.dart';
import '../features/users/presentation/account_page.dart';
import '../features/users/presentation/profile_page.dart';
import '../features/users/presentation/user_form_page.dart';
import '../features/users/presentation/users_page.dart';
import '../features/visits/presentation/add_visit_page.dart';
import '../shared/ds/ds_frame.dart';
import '../shared/ds/ds_nav_shell.dart';
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
        path: Routes.signedOut,
        builder: (BuildContext context, GoRouterState state) =>
            const SignedOutPage(),
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
        path: Routes.adminNotifications,
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationsPage(),
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

StatefulShellRoute _userShell(GlobalKey<NavigatorState> rootKey) =>
    StatefulShellRoute.indexedStack(
      builder:
          (
            BuildContext context,
            GoRouterState state,
            StatefulNavigationShell s,
          ) => DsNavShell(
            shell: s,
            items: const <DsNavItem>[
              DsNavItem(icon: DsIcons.home, label: 'Home'),
              DsNavItem(icon: DsIcons.map, label: 'Map'),
              DsNavItem(icon: DsIcons.history, label: 'History'),
              DsNavItem(icon: DsIcons.profile, label: 'Profile'),
            ],
          ),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.userHome,
              builder: (BuildContext context, GoRouterState state) =>
                  const HomePage(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'notifications',
                  parentNavigatorKey: rootKey,
                  builder: (BuildContext context, GoRouterState state) =>
                      const MyNotificationsPage(),
                ),
                GoRoute(
                  path: 'visit/:dayId',
                  parentNavigatorKey: rootKey,
                  builder: (BuildContext context, GoRouterState state) =>
                      AddVisitPage(
                        dayId: int.parse(state.pathParameters['dayId']!),
                      ),
                ),
                GoRoute(
                  path: 'requests',
                  parentNavigatorKey: rootKey,
                  builder: (BuildContext context, GoRouterState state) =>
                      const MyRequestsPage(),
                  routes: <RouteBase>[
                    // Fixed names before ':id', so they are not read as ids.
                    GoRoute(
                      path: 'attendance',
                      parentNavigatorKey: rootKey,
                      builder: (BuildContext context, GoRouterState state) =>
                          const AttendanceRequestPage(),
                    ),
                    GoRoute(
                      path: 'leave',
                      parentNavigatorKey: rootKey,
                      builder: (BuildContext context, GoRouterState state) =>
                          const LeaveRequestPage(),
                    ),
                    GoRoute(
                      path: ':id',
                      parentNavigatorKey: rootKey,
                      builder: (BuildContext context, GoRouterState state) =>
                          MyRequestDetailPage(
                            requestId: int.parse(state.pathParameters['id']!),
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
                  const ProfilePage(),
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
      builder: (
        BuildContext context,
        GoRouterState state,
        StatefulNavigationShell s,
      ) => AdminNavShell(shell: s),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.adminDashboard,
              builder: (BuildContext context, GoRouterState state) =>
                  const AdminDashboardPage(),
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
            GoRoute(
              path: Routes.adminRequests,
              builder: (BuildContext context, GoRouterState state) =>
                  const AdminRequestsPage(),
              routes: <RouteBase>[
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: rootKey,
                  builder: (BuildContext context, GoRouterState state) =>
                      RequestDetailPage(
                        requestId: int.parse(state.pathParameters['id']!),
                      ),
                ),
              ],
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
            GoRoute(
              path: Routes.adminReports,
              builder: (BuildContext context, GoRouterState state) =>
                  const ReportsPage(),
            ),
          ],
        ),
      ],
    );
