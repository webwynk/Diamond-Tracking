import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/entities/admin_notification.dart';
import 'package:diamond_tracking/domain/repositories/notification_repository.dart';
import 'package:diamond_tracking/features/admin/map/presentation/controllers/admin_live_map_controller.dart';
import 'package:diamond_tracking/features/admin/notifications/presentation/admin_notification_centre_page.dart';
import 'package:diamond_tracking/features/admin/notifications/presentation/controllers/admin_notification_controller.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/admin_route_view_page.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/controllers/admin_route_view_controller.dart';
import 'package:diamond_tracking/features/admin/shell/admin_tab.dart';
import 'package:diamond_tracking/shared/widgets/app_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_employee_repository.dart';
import 'support/fake_live_locations.dart';
import 'support/fake_notification_repository.dart';
import 'support/fake_route.dart';

void main() {
  late FakeNotificationRepository server;
  late FakeEmployeeRepository roster;
  late FakeLiveLocationRepository live;
  late FakeRouteRepository routes;

  setUp(() {
    server = FakeNotificationRepository();
    roster = FakeEmployeeRepository(
      roster: [
        rosterEmployee('e-asha', 'Asha Patil', 'DA-101'),
        rosterEmployee('e-ravi', 'Ravi Kumar', 'DA-102'),
      ],
    );
    live = FakeLiveLocationRepository();
    routes = FakeRouteRepository();
  });

  /// A notification [ago] before 10:00 IST on Saturday 17 October 2026.
  AdminNotification at(
    int id, {
    AdminNotificationType type = AdminNotificationType.dutyOn,
    String employeeId = 'e-asha',
    Duration ago = const Duration(minutes: 5),
    Map<String, dynamic> details = const <String, dynamic>{},
  }) => notification(
    id,
    type: type,
    employeeId: employeeId,
    ago: ago,
    now: kRouteNow,
    details: details,
  );

  Future<ProviderContainer> openCentre(
    WidgetTester tester, {
    VoidCallback? onBack,
    bool settle = true,
  }) async {
    // Tall, so the whole list is laid out and nothing needs scrolling to.
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationOverride(server),
          // Also supplies the roster the notification names come from.
          ...liveMapOverrides(live, roster, clock: () => kRouteNow),
          routeRepositoryProvider.overrideWithValue(routes),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Center(child: Text('home'))),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.text('home')),
    );
    // Home keeps this alive in the app; here the test does.
    container.listen(adminNotificationControllerProvider, (_, _) {});
    Navigator.of(tester.element(find.text('home'))).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminNotificationCentrePage(onBack: onBack),
      ),
    );
    // Let the page finish sliding in; taps land where the widgets really are.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    if (settle) await settleFrames(tester);
    return container;
  }

  /// The centre owns timers, so the tree is taken down before the test ends
  /// (the framework checks for timers before tear-down callbacks).
  Future<void> close(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  group('the list', () {
    testWidgets('shows who, what and when (IST), newest first', (tester) async {
      server.all = [
        at(3, type: AdminNotificationType.noSignal, employeeId: 'e-ravi'),
        at(
          2,
          type: AdminNotificationType.batteryLow,
          details: {'battery_level': 12},
          ago: const Duration(minutes: 40),
        ),
        at(1, ago: const Duration(hours: 1)),
      ];
      await openCentre(tester);

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Ravi Kumar (DA-102)'), findsOneWidget);
      expect(find.text('No location received for 10+ minutes'), findsOneWidget);
      expect(find.text('Battery low (12%)'), findsOneWidget);
      expect(find.text('Started duty'), findsOneWidget);
      // 04:25 UTC is 9:55 AM IST.
      expect(find.text('9:55 AM'), findsOneWidget);
      expect(find.text('9:20 AM'), findsOneWidget);
      expect(find.text('9:00 AM'), findsOneWidget);
      final first = tester.getTopLeft(find.byKey(const Key('notif-tile-3'))).dy;
      final last = tester.getTopLeft(find.byKey(const Key('notif-tile-1'))).dy;
      expect(first, lessThan(last));
      await close(tester);
    });

    testWidgets('words every kind of notification', (tester) async {
      server.all = [
        at(
          7,
          type: AdminNotificationType.dutyOff,
          details: {'status': 'blocked'},
        ),
        at(6, type: AdminNotificationType.dutyOff),
        at(5, type: AdminNotificationType.dutyAutoEnded),
        at(4, type: AdminNotificationType.mockGps),
        at(
          3,
          type: AdminNotificationType.noSignal,
          details: {'never_sent': true},
        ),
        at(
          2,
          type: AdminNotificationType.noSignal,
          details: {'last_seen': '2026-10-17T04:00:00+00:00'},
        ),
        at(1, type: AdminNotificationType.batteryLow),
      ];
      await openCentre(tester);

      expect(find.text('Ended duty (employee was blocked)'), findsOneWidget);
      expect(find.text('Ended duty'), findsOneWidget);
      expect(find.text('Duty ended automatically at 23:00'), findsOneWidget);
      expect(find.text('Fake GPS detected'), findsOneWidget);
      expect(
        find.text('No location received since duty started'),
        findsOneWidget,
      );
      // 04:00 UTC is 9:30 AM IST.
      expect(find.text('No location received since 9:30 AM'), findsOneWidget);
      expect(find.text('Battery low'), findsOneWidget);
      await close(tester);
    });

    testWidgets('someone the roster does not know is "An employee"', (
      tester,
    ) async {
      server.all = [at(1, employeeId: 'e-unknown')];
      await openCentre(tester);

      expect(find.text('An employee'), findsOneWidget);
      await close(tester);
    });

    testWidgets('groups by the IST day: Today, Yesterday, then the date', (
      tester,
    ) async {
      // Exact instants, so the IST day boundaries are what is tested.
      server.all = [
        AdminNotification(
          id: 4,
          type: AdminNotificationType.dutyOn,
          employeeId: 'e-asha',
          createdAt: DateTime.utc(2026, 10, 16, 20), // 01:30 IST, 17 Oct
        ),
        AdminNotification(
          id: 3,
          type: AdminNotificationType.dutyOn,
          employeeId: 'e-asha',
          createdAt: DateTime.utc(2026, 10, 16, 18), // 23:30 IST, 16 Oct
        ),
        AdminNotification(
          id: 2,
          type: AdminNotificationType.dutyOn,
          employeeId: 'e-asha',
          createdAt: DateTime.utc(2026, 10, 14, 5), // 14 Oct
        ),
      ];
      await openCentre(tester);

      expect(find.byKey(const Key('notif-day-Today')), findsOneWidget);
      expect(find.byKey(const Key('notif-day-Yesterday')), findsOneWidget);
      expect(find.byKey(const Key('notif-day-Wed, 14 Oct')), findsOneWidget);
      // The 01:30 IST one is under Today, the 23:30 IST one under Yesterday.
      final today = tester
          .getTopLeft(find.byKey(const Key('notif-day-Today')))
          .dy;
      final tile4 = tester.getTopLeft(find.byKey(const Key('notif-tile-4'))).dy;
      final yesterday = tester
          .getTopLeft(find.byKey(const Key('notif-day-Yesterday')))
          .dy;
      final tile3 = tester.getTopLeft(find.byKey(const Key('notif-tile-3'))).dy;
      expect(today, lessThan(tile4));
      expect(tile4, lessThan(yesterday));
      expect(yesterday, lessThan(tile3));
      expect(find.text('EARLIER TODAY'), findsNothing);
      await close(tester);
    });
  });

  group('the number', () {
    testWidgets('on the title is the SERVER unread count, not the rows shown', (
      tester,
    ) async {
      server.all = [for (var id = 120; id >= 1; id--) at(id)];
      await openCentre(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('badge-unread-count-pill')),
          matching: find.text('99+'),
        ),
        findsOneWidget,
        reason: '120 unread, shown capped like every badge',
      );
      expect(find.byKey(const Key('notif-tile-120')), findsOneWidget);
      expect(
        find.byKey(const Key('notif-tile-90')),
        findsNothing,
        reason: 'only the first page is loaded',
      );
      await close(tester);
    });

    testWidgets('on the Unread chip too', (tester) async {
      server.all = [for (var id = 5; id >= 1; id--) at(id)];
      await openCentre(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('filter-chip-unread')),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('no pill when nothing is unread', (tester) async {
      await openCentre(tester);

      expect(find.byKey(const Key('badge-unread-count-pill')), findsNothing);
      await close(tester);
    });
  });

  group('filters', () {
    testWidgets('chips: unread, all, duty, alerts. No Visits chip yet', (
      tester,
    ) async {
      server.all = [at(1)];
      await openCentre(tester);

      expect(find.byKey(const Key('filter-chip-unread')), findsOneWidget);
      expect(find.byKey(const Key('filter-chip-all')), findsOneWidget);
      expect(find.byKey(const Key('filter-chip-duty')), findsOneWidget);
      expect(find.byKey(const Key('filter-chip-alerts')), findsOneWidget);
      expect(find.byKey(const Key('filter-chip-visits')), findsNothing);
      await close(tester);
    });

    testWidgets('Duty and Alerts ask the server for those types', (
      tester,
    ) async {
      server.all = [
        at(2, type: AdminNotificationType.mockGps),
        at(1, type: AdminNotificationType.dutyOn),
      ];
      await openCentre(tester);

      await tester.tap(find.byKey(const Key('filter-chip-alerts')));
      await settleFrames(tester);
      expect(find.text('Fake GPS detected'), findsOneWidget);
      expect(find.text('Started duty'), findsNothing);

      await tester.tap(find.byKey(const Key('filter-chip-duty')));
      await settleFrames(tester);
      expect(find.text('Started duty'), findsOneWidget);
      expect(find.text('Fake GPS detected'), findsNothing);
      await close(tester);
    });

    testWidgets('All shows what was already read; Unread does not', (
      tester,
    ) async {
      server.all = [at(2), at(1)];
      server.read.add(1);
      await openCentre(tester);
      expect(find.byKey(const Key('notif-tile-1')), findsNothing);
      expect(find.byKey(const Key('notif-tile-2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('filter-chip-all')));
      await settleFrames(tester);
      expect(find.byKey(const Key('notif-tile-1')), findsOneWidget);
      await close(tester);
    });

    testWidgets('typing an employee narrows the list after a pause', (
      tester,
    ) async {
      server.all = [at(2, employeeId: 'e-ravi'), at(1, employeeId: 'e-asha')];
      await openCentre(tester);

      await tester.enterText(
        find.byKey(const Key('input-notif-employee')),
        'ravi',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await settleFrames(tester);

      expect(find.text('Ravi Kumar (DA-102)'), findsOneWidget);
      expect(find.text('Asha Patil (DA-101)'), findsNothing);

      await tester.tap(find.byKey(const Key('btn-notif-clear-employee')));
      await tester.pump(const Duration(milliseconds: 400));
      await settleFrames(tester);
      expect(find.text('Asha Patil (DA-101)'), findsOneWidget);
      await close(tester);
    });

    testWidgets('an employee nobody has that name says so', (tester) async {
      server.all = [at(1)];
      await openCentre(tester);

      await tester.enterText(
        find.byKey(const Key('input-notif-employee')),
        'zzz',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await settleFrames(tester);

      expect(find.text('No notifications for that employee'), findsOneWidget);
      await close(tester);
    });
  });

  group('older ones', () {
    testWidgets('a button loads the next page; the end is marked', (
      tester,
    ) async {
      server.all = [for (var id = 40; id >= 1; id--) at(id)];
      await openCentre(tester);
      expect(find.byKey(const Key('notif-tile-10')), findsNothing);
      expect(find.byKey(const Key('notif-tile-11')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-notif-load-more')));
      await settleFrames(tester);

      expect(find.byKey(const Key('notif-end')), findsOneWidget);
      expect(find.byKey(const Key('btn-notif-load-more')), findsNothing);
      expect(server.pageCalls.last.before, 11);
      await close(tester);
    });

    testWidgets('a failed page says so and offers to try again', (
      tester,
    ) async {
      server.all = [for (var id = 40; id >= 1; id--) at(id)];
      await openCentre(tester);

      server.pageError = const NetworkException();
      await tester.tap(find.byKey(const Key('btn-notif-load-more')));
      await settleFrames(tester);

      expect(find.byKey(const Key('notif-load-more-failed')), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await close(tester);
    });
  });

  group('states', () {
    testWidgets('loading shows the skeleton, not "all caught up"', (
      tester,
    ) async {
      server.gateCall(1);
      await openCentre(tester, settle: false);
      await tester.pump();

      expect(
        find.byKey(const Key('skeleton-notification-list')),
        findsOneWidget,
      );
      expect(find.text("You're all caught up"), findsNothing);

      server.release(1);
      await settleFrames(tester);
      expect(find.byKey(const Key('skeleton-notification-list')), findsNothing);
      await close(tester);
    });

    testWidgets('nothing unread says so', (tester) async {
      await openCentre(tester);

      expect(find.text("You're all caught up"), findsOneWidget);
      await close(tester);
    });

    testWidgets('each empty filter says what it is', (tester) async {
      await openCentre(tester);

      await tester.tap(find.byKey(const Key('filter-chip-all')));
      await settleFrames(tester);
      expect(find.text('No notifications yet'), findsOneWidget);

      await tester.tap(find.byKey(const Key('filter-chip-duty')));
      await settleFrames(tester);
      expect(find.text('No duty notifications'), findsOneWidget);

      await tester.tap(find.byKey(const Key('filter-chip-alerts')));
      await settleFrames(tester);
      expect(find.text('No alerts'), findsOneWidget);
      await close(tester);
    });

    testWidgets('a failed load is an error with Retry, then recovers', (
      tester,
    ) async {
      server.pageError = const NetworkException();
      await openCentre(tester);

      expect(find.byKey(const Key('notif-error')), findsOneWidget);
      expect(find.text("You're all caught up"), findsNothing);

      server.pageError = null;
      server.all = [at(1)];
      await tester.tap(find.text('Retry'));
      await settleFrames(tester);

      expect(find.byKey(const Key('notif-error')), findsNothing);
      expect(find.text('Started duty'), findsOneWidget);
      await close(tester);
    });

    testWidgets('a failed refresh keeps the list and warns it may be old', (
      tester,
    ) async {
      server.all = [at(1)];
      await openCentre(tester);

      server.pageError = const NetworkException();
      await tester.pump(const Duration(minutes: 1));
      await settleFrames(tester);

      expect(find.byKey(const Key('notif-refresh-failed')), findsOneWidget);
      expect(find.text('Started duty'), findsOneWidget);
      await close(tester);
    });

    testWidgets('pull to refresh reads again', (tester) async {
      server.all = [at(1)];
      await openCentre(tester);
      final calls = server.pageCalls.length;

      await tester.fling(
        find.byType(SingleChildScrollView).last,
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await settleFrames(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(server.pageCalls.length, greaterThan(calls));
      await close(tester);
    });

    testWidgets('back goes back', (tester) async {
      var backed = false;
      await openCentre(tester, onBack: () => backed = true);

      await tester.tap(find.byKey(const Key('btn-notif-back')));

      expect(backed, isTrue);
      await close(tester);
    });

    testWidgets('uses the shared top bar', (tester) async {
      await openCentre(tester);

      expect(find.byType(AppTopBar), findsOneWidget);
      await close(tester);
    });
  });

  group('live', () {
    testWidgets('a new notification appears and the number rises', (
      tester,
    ) async {
      server.all = [at(1)];
      await openCentre(tester);

      server.all = [at(2, type: AdminNotificationType.mockGps), ...server.all];
      server.emit(NotificationArrived(server.all.first));
      await tester.pump();

      expect(find.text('Fake GPS detected'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('badge-unread-count-pill')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      await close(tester);
    });
  });

  group('marking read', () {
    testWidgets('Mark all read clears the unread list and the number', (
      tester,
    ) async {
      server.all = [at(2), at(1)];
      await openCentre(tester);

      await tester.tap(find.byKey(const Key('btn-mark-all-read')));
      await settleFrames(tester);

      expect(server.markAllCalls, 1);
      expect(find.byKey(const Key('badge-unread-count-pill')), findsNothing);
      expect(find.text("You're all caught up"), findsOneWidget);
      await close(tester);
    });

    testWidgets('Mark all read is off when nothing is unread', (tester) async {
      await openCentre(tester);

      final button = tester.widget<TextButton>(
        find.byKey(const Key('btn-mark-all-read')),
      );
      expect(button.onPressed, isNull);
      await close(tester);
    });

    testWidgets('a refusal is shown, and the notification is unread again', (
      tester,
    ) async {
      server.all = [at(1)];
      await openCentre(tester);
      server.markError = const NetworkException();

      await tester.tap(find.byKey(const Key('notif-tile-1')));
      await settleFrames(tester);
      // The route screen opened; go back to the centre to see the message.
      Navigator.of(tester.element(find.byType(AdminRouteViewPage))).pop();
      await tester.pumpAndSettle();

      expect(
        find.text('Could not mark it as read. Please try again.'),
        findsOneWidget,
      );
      await close(tester);
    });
  });

  group('tapping one', () {
    testWidgets(
      'a duty event marks it read and opens that employees route for that IST day',
      (tester) async {
        server.all = [at(1)];
        await openCentre(tester);

        await tester.tap(find.byKey(const Key('notif-tile-1')));
        await tester.pumpAndSettle();

        expect(server.markReadCalls, [
          [1],
        ]);
        expect(find.byType(AdminRouteViewPage), findsOneWidget);
        expect(find.text('Asha Patil · Sat, 17 Oct'), findsOneWidget);
        expect(routes.calls.single.employeeId, 'e-asha');
        expect(routes.calls.single.dayStartUtc, istDayStartUtc(2026, 10, 17));
        await close(tester);
      },
    );

    testWidgets('an older notification opens the day it happened', (
      tester,
    ) async {
      server.all = [
        AdminNotification(
          id: 1,
          type: AdminNotificationType.dutyAutoEnded,
          employeeId: 'e-ravi',
          // 22:30 UTC on the 13th is 04:00 IST on the 14th.
          createdAt: DateTime.utc(2026, 10, 13, 22, 30),
        ),
      ];
      await openCentre(tester);

      await tester.tap(find.byKey(const Key('notif-tile-1')));
      await tester.pumpAndSettle();

      expect(find.text('Ravi Kumar · Wed, 14 Oct'), findsOneWidget);
      await close(tester);
    });

    testWidgets('an alert about someone ON DUTY opens the live map on them', (
      tester,
    ) async {
      live.positions = [livePosition('e-asha')];
      server.all = [at(1, type: AdminNotificationType.noSignal)];
      final container = await openCentre(tester);
      container.listen(adminLiveMapControllerProvider, (_, _) {});
      // The tab provider is auto-disposed: something must be listening.
      final tab = container.listen(adminTabProvider, (_, _) {});
      await settleFrames(tester);

      await tester.tap(find.byKey(const Key('notif-tile-1')));
      await tester.pumpAndSettle();

      expect(tab.read(), AdminTab.map);
      expect(container.read(liveMapFocusProvider), 'e-asha');
      expect(
        find.byType(AdminNotificationCentrePage),
        findsNothing,
        reason: 'back at the shell',
      );
      expect(find.byType(AdminRouteViewPage), findsNothing);
      expect(server.markReadCalls, [
        [1],
      ]);
      await close(tester);
    });

    testWidgets('an alert about someone no longer on duty opens their route', (
      tester,
    ) async {
      server.all = [at(1, type: AdminNotificationType.batteryLow)];
      final container = await openCentre(tester);
      container.listen(adminLiveMapControllerProvider, (_, _) {});
      await settleFrames(tester);

      await tester.tap(find.byKey(const Key('notif-tile-1')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminRouteViewPage), findsOneWidget);
      expect(container.read(liveMapFocusProvider), isNull);
      await close(tester);
    });

    testWidgets('a duty event about someone on duty still opens the route', (
      tester,
    ) async {
      live.positions = [livePosition('e-asha')];
      server.all = [at(1, type: AdminNotificationType.dutyOn)];
      final container = await openCentre(tester);
      container.listen(adminLiveMapControllerProvider, (_, _) {});
      await settleFrames(tester);

      await tester.tap(find.byKey(const Key('notif-tile-1')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminRouteViewPage), findsOneWidget);
      await close(tester);
    });
  });
}

/// Lets queued async work finish.
Future<void> settleFrames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}
