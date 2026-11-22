import 'dart:async';

import 'package:diamond_tracking/app/app.dart';
import 'package:diamond_tracking/core/supabase/supabase_providers.dart';
import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/auth/application/auth_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/duty/application/duty_providers.dart';
import 'package:diamond_tracking/features/notifications/application/notifications_providers.dart';
import 'package:diamond_tracking/features/notifications/application/push_service.dart';
import 'package:diamond_tracking/features/requests/application/requests_providers.dart';
import 'package:diamond_tracking/features/routes/application/route_providers.dart';
import 'package:diamond_tracking/features/tracking/application/tracker_providers.dart';
import 'package:diamond_tracking/features/users/application/users_providers.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:diamond_tracking/features/visits/application/visits_providers.dart';
import 'package:diamond_tracking/shared/ds/ds_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('splash, then login when signed out', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);

    auth.add(const SignedOut());
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('an employee gets the 4 user tabs', (WidgetTester tester) async {
    await pumpApp(tester);
    auth.add(
      const SignedIn(
        userId: 'u',
        role: AppRole.employee,
        mustChangePassword: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DsNavBar), findsOneWidget);
    for (final String tab in <String>['Home', 'Map', 'History', 'Profile']) {
      expect(find.bySemanticsLabel(tab), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Team'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Map'));
    await tester.pumpAndSettle();
    expect(find.text('My map'), findsWidgets);
    expect(find.textContaining('No route today'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('History'));
    await tester.pumpAndSettle();
    expect(find.text('No days yet'), findsOneWidget);
  });

  testWidgets('an admin gets the admin tabs, and sign-out returns to login', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    auth.add(
      const SignedIn(
        userId: 'a',
        role: AppRole.admin,
        mustChangePassword: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DsNavBar), findsOneWidget);
    for (final String tab in <String>[
      'Home',
      'Live',
      'Requests',
      'Team',
      'Reports',
    ]) {
      expect(find.bySemanticsLabel(tab), findsOneWidget);
    }
    expect(find.text('Hi, Boss'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Live'));
    await tester.pumpAndSettle();
    expect(find.text('Nobody on duty yet'), findsOneWidget);

    // The phone was registered for push after sign-in.
    expect(notifications.calls, contains('set:test-device-0001:push-token-1'));

    // A tapped push opens the request it is about.
    push.openedController.add(const PushOpen(requestId: 5));
    await tester.pumpAndSettle();
    expect(find.text('Request not found'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Signed out by someone else (here: the stream), not by Log out: the
    // app says so before the sign-in screen.
    auth.add(const SignedOut());
    await tester.pumpAndSettle();
    expect(find.textContaining('You were signed out.'), findsOneWidget);
    expect(find.byType(DsNavBar), findsNothing);
    await tester.ensureVisible(find.text('Sign in again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in again'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('a temporary PIN opens the set-password screen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    auth.add(
      const SignedIn(
        userId: 'u',
        role: AppRole.employee,
        mustChangePassword: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Choose your password.'), findsWidgets);
  });

  testWidgets('the Profile tab shows the user and logs out', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    auth.add(
      const SignedIn(
        userId: 'u',
        role: AppRole.employee,
        mustChangePassword: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Asha Roy'), findsOneWidget);

    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    expect(find.text('Current password'), findsOneWidget);
    expect(find.byType(DsNavBar), findsNothing);
  });

  testWidgets('an admin opens Users and their own account', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    auth.add(
      const SignedIn(
        userId: 'a',
        role: AppRole.admin,
        mustChangePassword: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Team'));
    await tester.pumpAndSettle();
    expect(find.text('Asha Roy'), findsOneWidget);

    await tester.tap(find.text('Asha Roy'));
    await tester.pumpAndSettle();
    expect(find.text('Edit user'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('My account'));
    await tester.pumpAndSettle();
    expect(find.text('My account'), findsWidgets);
    expect(find.text('Boss'), findsOneWidget);
  });
}
