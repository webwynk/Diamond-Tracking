import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/domain/auth_status.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/splash_page.dart';
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

  final GoRouter router = GoRouter(
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
        path: Routes.setPassword,
        builder: (BuildContext context, GoRouterState state) =>
            const SetPasswordPage(),
      ),
      _userShell(),
      _adminShell(),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    status.dispose();
  });
  return router;
});

GoRoute _tab(String path, String title, String phase, IconData icon) => GoRoute(
  path: path,
  builder: (BuildContext context, GoRouterState state) =>
      ComingSoonPage(title: title, phase: phase, icon: icon),
);

StatefulShellRoute _userShell() => StatefulShellRoute.indexedStack(
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
        _tab(Routes.userHome, 'Home', 'phase 4 (duty)', Icons.home_rounded),
      ],
    ),
    StatefulShellBranch(
      routes: <RouteBase>[
        _tab(Routes.userMap, 'My map', 'phase 5 (maps)', Icons.map_rounded),
      ],
    ),
    StatefulShellBranch(
      routes: <RouteBase>[
        _tab(
          Routes.userHistory,
          'History',
          'phase 5 (maps)',
          Icons.calendar_month_rounded,
        ),
      ],
    ),
    StatefulShellBranch(
      routes: <RouteBase>[
        _tab(
          Routes.userProfile,
          'Profile',
          'phase 3 (login and users)',
          Icons.person_rounded,
        ),
      ],
    ),
  ],
);

StatefulShellRoute _adminShell() => StatefulShellRoute.indexedStack(
  builder:
      (BuildContext context, GoRouterState state, StatefulNavigationShell s) =>
          NavShell(
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
        ),
      ],
    ),
    StatefulShellBranch(
      routes: <RouteBase>[
        _tab(
          Routes.adminLiveMap,
          'Live map',
          'phase 5 (maps)',
          Icons.location_on_rounded,
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
        ),
      ],
    ),
    StatefulShellBranch(
      routes: <RouteBase>[
        _tab(
          Routes.adminUsers,
          'Users',
          'phase 3 (login and users)',
          Icons.group_rounded,
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
        ),
      ],
    ),
  ],
);
