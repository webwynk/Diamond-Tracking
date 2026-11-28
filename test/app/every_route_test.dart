import 'dart:async';

import 'package:diamond_tracking/app/app.dart';
import 'package:diamond_tracking/app/router.dart';
import 'package:diamond_tracking/core/supabase/supabase_providers.dart';
import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/admin/presentation/admin_dashboard_page.dart';
import 'package:diamond_tracking/features/auth/application/auth_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/auth/presentation/change_password_page.dart';
import 'package:diamond_tracking/features/duty/application/duty_providers.dart';
import 'package:diamond_tracking/features/duty/presentation/home_page.dart';
import 'package:diamond_tracking/features/notifications/application/notifications_providers.dart';
import 'package:diamond_tracking/features/notifications/presentation/my_notifications_page.dart';
import 'package:diamond_tracking/features/notifications/presentation/notifications_page.dart';
import 'package:diamond_tracking/features/reports/presentation/reports_page.dart';
import 'package:diamond_tracking/features/requests/application/requests_providers.dart';
import 'package:diamond_tracking/features/requests/presentation/admin_requests_page.dart';
import 'package:diamond_tracking/features/requests/presentation/attendance_request_page.dart';
import 'package:diamond_tracking/features/requests/presentation/leave_request_page.dart';
import 'package:diamond_tracking/features/requests/presentation/my_request_detail_page.dart';
import 'package:diamond_tracking/features/requests/presentation/my_requests_page.dart';
import 'package:diamond_tracking/features/requests/presentation/request_detail_page.dart';
import 'package:diamond_tracking/features/routes/application/route_providers.dart';
import 'package:diamond_tracking/features/routes/presentation/day_route_page.dart';
import 'package:diamond_tracking/features/routes/presentation/duty_history_page.dart';
import 'package:diamond_tracking/features/routes/presentation/history_page.dart';
import 'package:diamond_tracking/features/routes/presentation/live_map_page.dart';
import 'package:diamond_tracking/features/routes/presentation/my_map_page.dart';
import 'package:diamond_tracking/features/tracking/application/tracker_providers.dart';
import 'package:diamond_tracking/features/users/application/users_providers.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:diamond_tracking/features/users/presentation/account_page.dart';
import 'package:diamond_tracking/features/users/presentation/employee_profile_page.dart';
import 'package:diamond_tracking/features/users/presentation/profile_page.dart';
import 'package:diamond_tracking/features/users/presentation/user_form_page.dart';
import 'package:diamond_tracking/features/users/presentation/users_page.dart';
import 'package:diamond_tracking/features/visits/application/visits_providers.dart';
import 'package:diamond_tracking/features/visits/presentation/add_visit_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fakes.dart';

void main() {
  late StreamController<AuthStatus> auth;
  FakePushService push = FakePushService();
  FakeNotificationsRepository notifications = FakeNotificationsRepository();

  setUp(() {
    auth = StreamController<AuthStatus>();
    push = FakePushService();
    notifications = FakeNotificationsRepository();
  });
  tearDown(() => auth.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStatusStreamProvider.overrideWithValue(auth.stream),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          dutyRepositoryProvider.overrideWithValue(FakeDutyRepository()),
          phoneSetupProvider.overrideWithValue(FakePhoneSetup()),
          trackerControlProvider.overrideWithValue(FakeTrackerControl()),
          serverClockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 11, 20, 6)).clock,
          ),
          deviceIdStoreProvider.overrideWithValue(FakeDeviceIdStore()),
          routeRepositoryProvider.overrideWithValue(FakeRouteRepository()),
          showGoogleMapProvider.overrideWithValue(false),
          visitsRepositoryProvider.overrideWithValue(FakeVisitsRepository()),
          notificationsRepositoryProvider.overrideWithValue(notifications),
          pushServiceProvider.overrideWithValue(push),
          requestsRepositoryProvider.overrideWithValue(
            FakeRequestsRepository(),
          ),
          usersRepositoryProvider.overrideWithValue(
            FakeUsersRepository(<Profile>[
              profile('u', name: 'Asha Roy'),
              profile('a', name: 'Boss', role: AppRole.admin),
            ]),
          ),
        ],
        child: const DiamondApp(),
      ),
    );
    await tester.pump();
  }

  Future<GoRouter> signIn(WidgetTester tester, AppRole role) async {
    await pumpApp(tester);
    auth.add(
      SignedIn(
        userId: role == AppRole.admin ? 'a' : 'u',
        role: role,
        mustChangePassword: false,
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(DiamondApp)))
        .read(routerProvider);
  }

  /// Opens [path] on the real router and checks which screen shows.
  Future<void> expectScreen(
    WidgetTester tester,
    GoRouter router,
    String path,
    Type page,
  ) async {
    router.go(path);
    await tester.pumpAndSettle();
    expect(
      find.byType(page),
      findsOneWidget,
      reason: '$path should show $page',
    );
  }

  testWidgets('every employee route opens its own screen', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await signIn(tester, AppRole.employee);
    final Map<String, Type> screens = <String, Type>{
      '/home': HomePage,
      '/map': MyMapPage,
      '/history': HistoryPage,
      '/profile': ProfilePage,
      '/profile/password': ChangePasswordPage,
      '/home/notifications': MyNotificationsPage,
      '/home/requests': MyRequestsPage,
      '/home/requests/attendance': AttendanceRequestPage,
      '/home/requests/leave': LeaveRequestPage,
      '/home/requests/5': MyRequestDetailPage,
      '/home/visit/1': AddVisitPage,
      '/history/day/1': DayRoutePage,
    };
    for (final MapEntry<String, Type> e in screens.entries) {
      await expectScreen(tester, router, e.key, e.value);
    }
  });

  testWidgets('an employee is turned away from every admin route', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await signIn(tester, AppRole.employee);
    for (final String path in <String>[
      '/admin',
      '/admin/live',
      '/admin/requests',
      '/admin/requests/1',
      '/admin/users',
      '/admin/users/new',
      '/admin/users/u',
      '/admin/users/u/edit',
      '/admin/users/u/days',
      '/admin/reports',
      '/admin/account',
      '/admin/account/password',
      '/admin/notifications',
      '/admin/days/1',
    ]) {
      await expectScreen(tester, router, path, HomePage);
    }
  });

  testWidgets('every admin route opens its own screen', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await signIn(tester, AppRole.admin);
    final Map<String, Type> screens = <String, Type>{
      '/admin': AdminDashboardPage,
      '/admin/live': LiveMapPage,
      '/admin/live?day=1': LiveMapPage,
      '/admin/requests': AdminRequestsPage,
      '/admin/requests/1': RequestDetailPage,
      '/admin/users': UsersPage,
      '/admin/users/new': UserFormPage,
      '/admin/users/u': EmployeeProfilePage,
      '/admin/users/u/edit': UserFormPage,
      '/admin/users/u/days': DutyHistoryPage,
      '/admin/reports': ReportsPage,
      '/admin/account': AccountPage,
      '/admin/account/password': ChangePasswordPage,
      '/admin/notifications': NotificationsPage,
      '/admin/days/1': DayRoutePage,
    };
    for (final MapEntry<String, Type> e in screens.entries) {
      await expectScreen(tester, router, e.key, e.value);
    }
  });

  testWidgets('an admin is turned away from every employee route', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await signIn(tester, AppRole.admin);
    for (final String path in <String>[
      '/home',
      '/map',
      '/history',
      '/profile',
      '/profile/password',
      '/home/notifications',
      '/home/requests',
      '/home/requests/leave',
      '/home/visit/1',
      '/history/day/1',
    ]) {
      await expectScreen(tester, router, path, AdminDashboardPage);
    }
  });

  testWidgets('employee buttons open the screens they say', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await signIn(tester, AppRole.employee);

    /// Opens [from], taps the button, and checks the screen that shows.
    Future<void> tapGoes(String from, Finder button, Type page) async {
      router.go(from);
      await tester.pumpAndSettle();
      await tester.tap(button.first);
      await tester.pumpAndSettle();
      expect(find.byType(page), findsOneWidget, reason: '$from -> $page');
    }

    final Finder bell = find.bySemanticsLabel(RegExp('^Notifications'));
    final Finder avatar = find.bySemanticsLabel('My profile');
    final Finder route = find.text('My route');
    final Finder requests = find.text('Requests');
    final Finder lateRequest = find.text('Request attendance');
    final Finder password = find.text('Change password');
    final Finder myRequests = find.text('My requests');

    await tapGoes('/home', bell, MyNotificationsPage);
    await tapGoes('/home', avatar, ProfilePage);
    await tapGoes('/home', route, MyMapPage);
    await tapGoes('/home', requests, MyRequestsPage);
    // The test clock is 11:30 IST: duty on is closed, so this shows.
    await tapGoes('/home', lateRequest, AttendanceRequestPage);
    await tapGoes('/profile', password, ChangePasswordPage);
    await tapGoes('/profile', myRequests, MyRequestsPage);
    await tapGoes('/home/requests', find.text('Leave'), LeaveRequestPage);
    await tapGoes(
      '/home/requests',
      find.text('Attendance'),
      AttendanceRequestPage,
    );
  });
}
