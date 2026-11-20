import 'package:diamond_tracking/app/routes.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/notifications/application/notifications_providers.dart';
import 'package:diamond_tracking/features/notifications/domain/app_notification.dart';
import 'package:diamond_tracking/features/notifications/presentation/notification_bell.dart';
import 'package:diamond_tracking/features/notifications/presentation/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  AppNotification n(int id, {int? request, bool read = false}) =>
      AppNotification(
        id: id,
        kind: 'leave_request',
        title: 'Leave request $id',
        body: 'Asha asked for 2 days',
        requestId: request,
        createdAt: DateTime.utc(2026, 11, 20, 5, id),
        readAt: read ? DateTime.utc(2026, 11, 20, 6) : null,
      );

  testWidgets('the bell counts unread notifications live', (
    WidgetTester tester,
  ) async {
    final FakeNotificationsRepository repo = FakeNotificationsRepository(
      <AppNotification>[n(1), n(2, read: true)],
    );
    await pumpPage(
      tester,
      Scaffold(appBar: AppBar(actions: const <Widget>[NotificationBell()])),
      notifications: repo,
    );
    expect(find.text('1'), findsOneWidget);
    repo.push(<AppNotification>[n(3), n(1), n(2, read: true)]);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byType(NotificationBell));
    await tester.pumpAndSettle();
    expect(find.text('route ${Routes.adminNotifications}'), findsOneWidget);
  });

  testWidgets('the list marks read and opens the request', (
    WidgetTester tester,
  ) async {
    final FakeNotificationsRepository repo = FakeNotificationsRepository(
      <AppNotification>[n(2, request: 9), n(1, read: true)],
    );
    await pumpPage(tester, const NotificationsPage(), notifications: repo);
    expect(find.text('Leave request 2'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);

    await tester.tap(find.text('Leave request 2'));
    await tester.pumpAndSettle();
    expect(repo.calls, <String>['read:2']);
    expect(find.text('route /admin/requests/9'), findsOneWidget);
  });

  testWidgets('mark all read', (WidgetTester tester) async {
    final FakeNotificationsRepository repo = FakeNotificationsRepository(
      <AppNotification>[n(2), n(1)],
    );
    await pumpPage(tester, const NotificationsPage(), notifications: repo);
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(repo.calls, <String>['read:all']);
    expect(find.text('Mark all read'), findsNothing);
  });

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
