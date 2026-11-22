import 'package:diamond_tracking/app/routes.dart';
import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/notifications/application/notifications_providers.dart';
import 'package:diamond_tracking/features/notifications/domain/app_notification.dart';
import 'package:diamond_tracking/features/notifications/presentation/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  // 2026-11-20 13:30 IST.
  final DateTime now = DateTime.utc(2026, 11, 20, 8);
  List<Override> clock() => <Override>[
    serverClockProvider.overrideWithValue(FixedClock(now).clock),
  ];

  AppNotification admin(
    int id,
    String kind,
    String body, {
    required DateTime at,
    int? request,
    bool read = false,
  }) => AppNotification(
    id: id,
    kind: kind,
    title: 'Title $id',
    body: body,
    requestId: request,
    createdAt: at,
    readAt: read ? at : null,
  );

  final List<AppNotification> sample = <AppNotification>[
    admin(
      3,
      'short_duty',
      'Rahul Das ended duty after 7 h 40 min',
      at: now.subtract(const Duration(hours: 1)),
      request: 30,
    ),
    admin(
      2,
      'leave_request',
      'Amit Roy asked for 3 day(s) of sick leave from 24 Nov',
      at: DateTime.utc(2026, 11, 19, 12, 45),
      request: 20,
      read: true,
    ),
    admin(
      1,
      'attendance_request',
      'Priya Ghosh asked for attendance on 17 Nov 2026',
      at: DateTime.utc(2026, 11, 18, 5),
      request: 10,
      read: true,
    ),
  ];

  testWidgets('groups by day, shows who and what, opens the request', (
    WidgetTester tester,
  ) async {
    final FakeNotificationsRepository repo = FakeNotificationsRepository(
      sample,
    );
    await pumpPage(
      tester,
      const NotificationsPage(),
      notifications: repo,
      overrides: clock(),
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    expect(find.text('Rahul Das'), findsOneWidget);
    expect(find.text('RD'), findsOneWidget);
    expect(find.text('1h ago'), findsOneWidget);
    expect(find.text('6:15 PM'), findsOneWidget);
    expect(find.text('18 Nov'), findsOneWidget);
    expect(find.textContaining('worked 7 h 40 min'), findsOneWidget);
    expect(find.textContaining('sick, 3 days from 24 Nov'), findsOneWidget);
    expect(find.textContaining('for 17 Nov 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('Unread, 1'), findsOneWidget);

    await tester.tap(find.text('Rahul Das'));
    await tester.pumpAndSettle();
    expect(repo.calls, <String>['read:3']);
    expect(find.text('route /admin/requests/30'), findsOneWidget);
  });

  testWidgets('filters: unread, short duty, requests', (
    WidgetTester tester,
  ) async {
    await pumpPage(
      tester,
      const NotificationsPage(),
      notifications: FakeNotificationsRepository(sample),
      overrides: clock(),
    );
    await tester.tap(find.bySemanticsLabel('Requests'));
    await tester.pumpAndSettle();
    expect(find.text('Rahul Das'), findsNothing);
    expect(find.text('Amit Roy'), findsOneWidget);
    expect(find.text('Priya Ghosh'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Short duty'));
    await tester.pumpAndSettle();
    expect(find.text('Rahul Das'), findsOneWidget);
    expect(find.text('Amit Roy'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Unread, 1'));
    await tester.pumpAndSettle();
    expect(find.text('Rahul Das'), findsOneWidget);
    expect(find.text('Priya Ghosh'), findsNothing);
  });

  testWidgets('mark all read', (WidgetTester tester) async {
    final FakeNotificationsRepository repo = FakeNotificationsRepository(
      sample,
    );
    await pumpPage(
      tester,
      const NotificationsPage(),
      notifications: repo,
      overrides: clock(),
    );
    await tester.tap(find.bySemanticsLabel('Mark all as read'));
    await tester.pumpAndSettle();
    expect(repo.calls, <String>['read:all']);
    expect(find.bySemanticsLabel('Mark all as read'), findsNothing);
  });

  testWidgets('nothing yet: all caught up', (WidgetTester tester) async {
    await pumpPage(
      tester,
      const NotificationsPage(),
      notifications: FakeNotificationsRepository(<AppNotification>[]),
      overrides: clock(),
    );
    expect(find.text("You're all caught up"), findsOneWidget);
  });

  test('unknown text falls back to the title and body', () {
    final AppNotification odd = admin(
      9,
      'leave_request',
      'Something else',
      at: now,
    );
    expect(adminNotificationText(odd), ('Title 9', 'Something else'));
  });

  for (final double width in <double>[360, 390, 430]) {
    testWidgets('fits ${width.toInt()} wide', (WidgetTester tester) async {
      tester.view.physicalSize = Size(width * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpPage(
        tester,
        const NotificationsPage(),
        notifications: FakeNotificationsRepository(<AppNotification>[
          admin(
            5,
            'leave_request',
            'Mohammad Hasanur Rahaman Chowdhury asked for 12 day(s) of sick '
                'leave from 24 Nov',
            at: now,
            request: 1,
          ),
          ...sample,
        ]),
        overrides: clock(),
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('a notification opens the right screen for each side', () {
    expect(notificationTarget(AppRole.admin, 4), '/admin/requests/4');
    expect(notificationTarget(AppRole.employee, 4), '/home/requests/4');
    expect(
      notificationTarget(AppRole.employee, null),
      Routes.userNotifications,
    );
    final AppNotification parsed = AppNotification.fromRow(<String, dynamic>{
      'id': 1,
      'kind': 'short_duty',
      'title': 'Short duty to review',
      'body': null,
      'data': <String, dynamic>{'request_id': 12, 'day': '2026-11-20'},
      'created_at': '2026-11-20T05:00:00+00:00',
      'read_at': null,
    });
    expect(parsed.requestId, 12);
    expect(parsed.unread, isTrue);
  });
}
