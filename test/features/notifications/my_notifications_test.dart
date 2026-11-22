import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/notifications/domain/app_notification.dart';
import 'package:diamond_tracking/features/notifications/presentation/my_notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  // 9:00 AM IST on 21 Nov 2026.
  final DateTime now = DateTime.utc(2026, 11, 21, 3, 30);
  const SignedIn employee = SignedIn(
    userId: 'u',
    role: AppRole.employee,
    mustChangePassword: false,
  );

  List<AppNotification> items() => <AppNotification>[
    AppNotification(
      id: 3,
      kind: 'request_decided',
      title: 'Leave rejected',
      body: 'Too many days.',
      requestId: 9,
      createdAt: DateTime.utc(2026, 11, 21, 2),
    ),
    AppNotification(
      id: 2,
      kind: 'duty_auto_off',
      title: 'Duty turned off at 11 PM',
      body: 'Your duty on 20 Nov ended by itself at 11:00 PM.',
      dutyDayId: 40,
      createdAt: DateTime.utc(2026, 11, 20, 17, 30),
      readAt: DateTime.utc(2026, 11, 20, 18),
    ),
    AppNotification(
      id: 1,
      kind: 'request_decided',
      title: 'Leave approved',
      requestId: 7,
      createdAt: DateTime.utc(2026, 11, 13, 5),
      readAt: DateTime.utc(2026, 11, 13, 6),
    ),
  ];

  Future<FakeNotificationsRepository> pump(WidgetTester tester) async {
    final FakeNotificationsRepository repo = FakeNotificationsRepository(
      items(),
    );
    await pumpPage(
      tester,
      const MyNotificationsPage(),
      status: employee,
      notifications: repo,
      overrides: [serverClockProvider.overrideWithValue(FixedClock(now).clock)],
    );
    return repo;
  }

  testWidgets('lists, filters, and marks all read', (
    WidgetTester tester,
  ) async {
    final FakeNotificationsRepository repo = await pump(tester);
    expect(find.text('1 unread'), findsOneWidget);
    expect(find.text('Admin: Too many days.'), findsOneWidget);
    expect(find.text('Tap to see the request'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('13 Nov'), findsOneWidget);

    await tester.tap(find.text('Duty'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsOneWidget);
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsNWidgets(2));

    await tester.tap(find.bySemanticsLabel('Mark all as read'));
    await tester.pumpAndSettle();
    expect(repo.calls, <String>['read:all']);
    expect(find.text('All read'), findsOneWidget);
  });

  testWidgets('a decision opens the request and is marked read', (
    WidgetTester tester,
  ) async {
    final FakeNotificationsRepository repo = await pump(tester);
    await tester.tap(find.text('Leave rejected'));
    await tester.pumpAndSettle();
    expect(repo.calls, <String>['read:3']);
    expect(find.text('route /home/requests/9'), findsOneWidget);
  });

  testWidgets('duty turned off at 11 PM opens that day', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Duty turned off at 11 PM'));
    await tester.pumpAndSettle();
    expect(find.text('route /history/day/40'), findsOneWidget);
  });

  test('the day is read from the notification data', () {
    final AppNotification n = AppNotification.fromRow(<String, dynamic>{
      'id': 1,
      'kind': 'duty_auto_off',
      'title': 't',
      'data': <String, dynamic>{'duty_day_id': 40, 'day': '2026-11-20'},
      'created_at': '2026-11-20T17:30:00Z',
    });
    expect(n.dutyDayId, 40);
    expect(n.requestId, isNull);
  });

  for (final double width in <double>[360, 390, 430]) {
    testWidgets('fits a $width wide phone', (WidgetTester tester) async {
      tester.view.physicalSize = Size(width * 3, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pump(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
