import 'dart:io';

import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/admin/presentation/admin_dashboard_page.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/notifications/application/notifications_providers.dart';
import 'package:diamond_tracking/features/notifications/domain/app_notification.dart';
import 'package:diamond_tracking/features/requests/application/requests_providers.dart';
import 'package:diamond_tracking/features/requests/domain/app_request.dart';
import 'package:diamond_tracking/features/routes/application/route_providers.dart';
import 'package:diamond_tracking/features/routes/domain/geo_point.dart';
import 'package:diamond_tracking/features/routes/domain/live_position.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:diamond_tracking/features/visits/domain/visit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  // Friday 20 Nov 2026, 11:30 AM IST.
  final DateTime now = DateTime.utc(2026, 11, 20, 6);
  final DateTime today = DateTime.utc(2026, 11, 20);
  late FakeRouteRepository routes;
  late FakeRequestsRepository requests;
  late FakeNotificationsRepository notifications;
  late FakeVisitsRepository visits;
  late FakeUsersRepository users;
  setUp(() {
    routes = FakeRouteRepository();
    requests = FakeRequestsRepository();
    notifications = FakeNotificationsRepository();
    visits = FakeVisitsRepository();
    users = FakeUsersRepository(<Profile>[
      profile('admin1', name: 'Arjun Sen', role: AppRole.admin),
      profile('u1', name: 'Rahul Das'),
      profile('u2', name: 'Priya Ghosh'),
      profile('u3', name: 'Amit Roy'),
      profile('u4', name: 'Kunal Paul'),
      profile('u5', name: 'Sneha Biswas'),
      profile('u6', name: 'Old Hand', active: false),
    ]);
  });

  List<Override> overrides() => <Override>[
    routeRepositoryProvider.overrideWithValue(routes),
    requestsRepositoryProvider.overrideWithValue(requests),
    serverClockProvider.overrideWithValue(FixedClock(now).clock),
    showGoogleMapProvider.overrideWithValue(false),
  ];

  Future<void> show(WidgetTester tester, {Size? size}) async {
    tester.view.physicalSize = size ?? const Size(1080, 4000);
    tester.view.devicePixelRatio = size == null ? 2 : 3;
    addTearDown(tester.view.reset);
    await pumpPage(
      tester,
      const AdminDashboardPage(),
      users: users,
      notifications: notifications,
      visits: visits,
      overrides: overrides(),
    );
  }

  DutyDay day(int id, String user, DayStatus status, {int? km}) => DutyDay(
    id: id,
    userId: user,
    day: today,
    status: status,
    dutyOnAt: status == DayStatus.leave ? null : now,
    distanceM: km == null ? null : km * 1000,
  );

  AppNotification note(int id, {bool unread = false, int? request}) =>
      AppNotification(
        id: id,
        kind: attendanceRequestKind,
        title: 'New attendance request',
        body: 'Rahul Das · for 19 Nov',
        requestId: request,
        createdAt: now.subtract(Duration(hours: id)),
        readAt: unread ? null : now,
      );

  void fillToday() {
    routes.days[1] = day(1, 'u1', DayStatus.onDuty, km: 30);
    routes.days[2] = day(2, 'u2', DayStatus.onDuty, km: 12);
    routes.days[3] = day(3, 'u3', DayStatus.leave);
    routes.initialLive = <LivePosition>[
      LivePosition(
        userId: 'u1',
        dutyDayId: 1,
        point: const GeoPoint(22.5, 88.3),
        recordedAt: now.subtract(const Duration(minutes: 1)),
      ),
      // Priya's last point is 20 minutes old: no location.
      LivePosition(
        userId: 'u2',
        dutyDayId: 2,
        point: const GeoPoint(22.5, 88.3),
        recordedAt: now.subtract(const Duration(minutes: 20)),
      ),
    ];
    visits.byDay[1] = <Visit>[
      for (int i = 0; i < 3; i++)
        Visit(
          id: 'v$i',
          storeName: 'Shop $i',
          fromGallery: true,
          capturedAt: now,
        ),
    ];
    requests.requests.add(
      AppRequest(
        id: 9,
        userId: 'u1',
        kind: RequestKind.attendance,
        status: RequestStatus.pending,
        createdAt: now,
        day: DateTime.utc(2026, 11, 19),
      ),
    );
  }

  testWidgets('today at a glance: on duty, visits, km and the four tiles', (
    WidgetTester tester,
  ) async {
    fillToday();
    await show(tester);
    expect(find.text('Fri, 20 Nov'), findsOneWidget);
    expect(find.text('Hi, Arjun'), findsOneWidget);
    expect(find.text('AS'), findsOneWidget);
    // 2 of the 5 active employees are on duty.
    expect(
      find.bySemanticsLabel('2 of 5 people on duty. Open live map.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Requests 1, Needs your decision')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'^No location 1,')), findsOneWidget);
    // Kunal and Sneha: no duty, no leave.
    expect(find.bySemanticsLabel(RegExp(r'^Not started 2,')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^On leave 1,')), findsOneWidget);
  });

  // Each button goes where its label says (every one checked, not assumed).
  final Map<String, String> buttons = <String, String>{
    'Notifications': '/admin/notifications',
    'My account': '/admin/account',
    '2 of 5 people on duty. Open live map.': '/admin/live',
    'No location 1, Check now': '/admin/live',
    'Not started 2, No duty on yet': '/admin/users',
    'On leave 1, Approved': '/admin/users',
  };
  for (final MapEntry<String, String> b in buttons.entries) {
    testWidgets('the "${b.key}" button opens ${b.value}', (
      WidgetTester tester,
    ) async {
      fillToday();
      await show(tester);
      await tester.tap(
        find.bySemanticsLabel(RegExp('^${RegExp.escape(b.key)}')).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('route ${b.value}'), findsOneWidget);
    });
  }

  testWidgets('the card and tiles open their tabs', (
    WidgetTester tester,
  ) async {
    fillToday();
    await show(tester);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Requests 1')));
    await tester.pumpAndSettle();
    expect(find.text('route /admin/requests'), findsOneWidget);
  });

  testWidgets('visits and km add up for everyone', (WidgetTester tester) async {
    fillToday();
    await show(tester);
    expect(find.text('3 visits · 42 km', findRichText: true), findsOneWidget);
  });

  testWidgets('recent notifications: 10 a page, unread first, open one', (
    WidgetTester tester,
  ) async {
    notifications.items = <AppNotification>[
      for (int i = 1; i <= 23; i++) note(i, unread: i <= 2, request: 40 + i),
    ];
    await show(tester);
    expect(find.text('2 new'), findsOneWidget);
    expect(find.text('1–10 of 23'), findsOneWidget);
    expect(find.text('New attendance request'), findsNWidgets(10));

    await tester.tap(find.bySemanticsLabel('Page 3'));
    await tester.pumpAndSettle();
    expect(find.text('21–23 of 23'), findsOneWidget);
    expect(find.text('New attendance request'), findsNWidgets(3));

    await tester.tap(find.bySemanticsLabel('Previous page'));
    await tester.pumpAndSettle();
    expect(find.text('11–20 of 23'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Page 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Unread\.')).first);
    await tester.pumpAndSettle();
    expect(notifications.calls, contains('read:1'));
    expect(find.text('route /admin/requests/41'), findsOneWidget);
  });

  testWidgets('no notifications says so; the centre link opens it', (
    WidgetTester tester,
  ) async {
    await show(tester);
    expect(find.text('No notifications yet'), findsOneWidget);
    await tester.tap(find.text('Open notification centre'));
    await tester.pumpAndSettle();
    expect(find.text('route /admin/notifications'), findsOneWidget);
  });

  testWidgets('a failed load shows Try again, and it refreshes by itself '
      '(L85)', (WidgetTester tester) async {
    routes.daysOnError = const SocketException('offline');
    await show(tester);
    expect(find.text("Couldn't load today"), findsOneWidget);

    routes.daysOnError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load today"), findsNothing);
    expect(
      find.bySemanticsLabel('0 of 5 people on duty. Open live map.'),
      findsOneWidget,
    );

    // Someone goes on duty; two minutes later the dashboard shows it.
    routes.days[1] = day(1, 'u1', DayStatus.onDuty);
    await tester.pump(dashboardRefreshEvery);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('1 of 5 people on duty. Open live map.'),
      findsOneWidget,
    );
  });

  for (final double width in <double>[360, 390, 430]) {
    testWidgets('the dashboard fits a $width wide phone', (
      WidgetTester tester,
    ) async {
      fillToday();
      notifications.items = <AppNotification>[
        for (int i = 1; i <= 60; i++) note(i, unread: i <= 3),
      ];
      await show(tester, size: Size(width * 3, 800 * 3));
      expect(tester.takeException(), isNull);
    });
  }
}
