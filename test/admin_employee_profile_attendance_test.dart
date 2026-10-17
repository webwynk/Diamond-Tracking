import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/admin_attendance_page.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/controllers/admin_attendance_controller.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_detail_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/admin_route_view_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_attendance.dart';
import 'support/fake_route.dart';

/// The Team profile's "This month" and "Recent duty" cards read the same
/// attendance feed as the attendance screen, so they cannot disagree with it.
void main() {
  late FakeAttendanceRepository attendance;
  late FakeRouteRepository routes;
  final october = istMonthStartUtc(2026, 10);

  const asha = AdminEmployeeItem(
    id: 'e1',
    name: 'Asha Patil',
    employeeCode: 'DA-101',
    phoneNumber: '+919820000101',
    status: AdminEmployeeStatus.onDuty,
  );

  setUp(() {
    attendance = FakeAttendanceRepository(
      employeeCreatedAt: DateTime.utc(2026, 9, 1, 3),
    );
    routes = FakeRouteRepository();
  });

  Future<void> pumpProfile(
    WidgetTester tester, {
    AdminEmployeeItem employee = asha,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // One phone clock for both: a provider may be overridden only once.
          attendanceRepositoryProvider.overrideWithValue(attendance),
          ...routeOverrides(routes),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AdminEmployeeDetailPage(employee: employee),
        ),
      ),
    );
    if (settle) {
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
    }
  }

  Finder inCard(String key, String text) =>
      find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

  testWidgets('"This month" shows the attendance totals', (tester) async {
    attendance.months[october] = [
      attendanceSession(
        'a',
        year: 2026,
        month: 10,
        day: 5,
        minutes: 480,
        km: 10,
        visits: 3,
      ),
      attendanceSession(
        'b',
        year: 2026,
        month: 10,
        day: 6,
        minutes: 90,
        km: 2.5,
        visits: 1,
        flagged: 2,
        status: 'auto_curfew',
      ),
    ];
    await pumpProfile(tester);

    expect(find.text('October'), findsOneWidget);
    expect(inCard('metric-days-worked', '2'), findsOneWidget);
    expect(inCard('metric-hours-worked', '9h 30m'), findsOneWidget);
    expect(inCard('metric-distance-km', '12.5 km'), findsOneWidget);
    expect(inCard('metric-visits-count', '4'), findsOneWidget);
    expect(find.text('1 day auto-ended'), findsOneWidget);
    expect(find.text('2 location flags'), findsOneWidget);
  });

  testWidgets('shows dashes while loading, never zeros', (tester) async {
    attendance.gate(october);
    await pumpProfile(tester, settle: false);
    await tester.pump();

    expect(inCard('metric-days-worked', '–'), findsOneWidget);
    expect(inCard('metric-hours-worked', '–'), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.text('No duty recorded this month.'), findsNothing);

    attendance.release(october);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(find.text('Loading…'), findsNothing);
  });

  testWidgets('shows dashes, not zeros, when the load failed', (tester) async {
    attendance.error = const NetworkException();
    await pumpProfile(tester);

    expect(inCard('metric-days-worked', '–'), findsOneWidget);
    expect(find.text("Couldn't load recent duty."), findsOneWidget);
    expect(find.text('No duty recorded this month.'), findsNothing);
  });

  testWidgets('"Recent duty" lists the latest days with duty, newest first', (
    tester,
  ) async {
    attendance.months[october] = [
      attendanceSession('a', year: 2026, month: 10, day: 5),
      attendanceSession(
        'b',
        year: 2026,
        month: 10,
        day: 6,
        startHour: 9,
        startMinute: 0,
        minutes: 60,
        km: 1,
      ),
      attendanceSession('c', year: 2026, month: 10, day: 7),
      attendanceSession('d', year: 2026, month: 10, day: 8),
    ];
    await pumpProfile(tester);

    // Only three, and not the absent days between them.
    expect(find.byKey(const Key('row-recent-duty-2026-10-08')), findsOneWidget);
    expect(find.byKey(const Key('row-recent-duty-2026-10-07')), findsOneWidget);
    expect(find.byKey(const Key('row-recent-duty-2026-10-06')), findsOneWidget);
    expect(find.byKey(const Key('row-recent-duty-2026-10-05')), findsNothing);
    expect(find.text('Thu, 8 Oct'), findsOneWidget);
    expect(find.text('8:04 AM – 3:30 PM'), findsWidgets);
    expect(find.text('7h 26m'), findsWidgets);
    expect(find.text('12.3 km'), findsWidgets);
  });

  testWidgets('a month with no duty says so', (tester) async {
    await pumpProfile(tester);

    expect(find.text('No duty recorded this month.'), findsOneWidget);
    expect(inCard('metric-days-worked', '0'), findsOneWidget);
  });

  testWidgets('"View all" opens the attendance screen for this employee', (
    tester,
  ) async {
    await pumpProfile(tester);

    await tester.ensureVisible(
      find.byKey(const Key('btn-recent-duty-view-all')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn-recent-duty-view-all')));
    await tester.pumpAndSettle();

    expect(find.byType(AdminAttendancePage), findsOneWidget);
    expect(find.text('Asha Patil · DA-101'), findsOneWidget);
  });

  testWidgets('the month chip opens the attendance screen too', (tester) async {
    await pumpProfile(tester);

    await tester.ensureVisible(
      find.byKey(const Key('btn-employee-select-month')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn-employee-select-month')));
    await tester.pumpAndSettle();

    expect(find.byType(AdminAttendancePage), findsOneWidget);
  });

  testWidgets('a recent day opens that days route', (tester) async {
    attendance.months[october] = [
      attendanceSession('a', year: 2026, month: 10, day: 8),
    ];
    await pumpProfile(tester);

    final row = find.byKey(const Key('row-recent-duty-2026-10-08'));
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(AdminRouteViewPage), findsOneWidget);
    expect(find.text('Asha Patil · Thu, 8 Oct'), findsOneWidget);
    expect(routes.calls.single.dayStartUtc, istDayStartUtc(2026, 10, 8));
  });

  testWidgets('a day opened from the attendance screen opens its route', (
    tester,
  ) async {
    attendance.months[october] = [
      attendanceSession('a', year: 2026, month: 10, day: 8),
    ];
    await pumpProfile(tester);
    await tester.ensureVisible(
      find.byKey(const Key('btn-recent-duty-view-all')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn-recent-duty-view-all')));
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('attendance-card-2026-10-08'));
    await tester.ensureVisible(card);
    await tester.pump();
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byType(AdminRouteViewPage), findsOneWidget);
    expect(find.text('Asha Patil · Thu, 8 Oct'), findsOneWidget);
  });

  testWidgets('the header does not invent hours for someone on duty', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(find.text('On duty'), findsOneWidget);
    expect(find.textContaining('7h 24m'), findsNothing);
  });

  testWidgets('"Route view" opens today, "Track live" is unchanged', (
    tester,
  ) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Route view'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminRouteViewPage), findsOneWidget);
    expect(find.text('Asha Patil · Sat, 17 Oct'), findsOneWidget);
  });
}
