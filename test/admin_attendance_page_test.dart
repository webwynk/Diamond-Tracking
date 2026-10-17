import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/admin_attendance_page.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/widgets/admin_attendance_daily_card.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/widgets/admin_attendance_filter_chips.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/widgets/admin_attendance_summary_card.dart';
import 'package:diamond_tracking/shared/widgets/app_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_attendance.dart';

void main() {
  late FakeAttendanceRepository repository;
  final october = istMonthStartUtc(2026, 10);

  setUp(() {
    repository = FakeAttendanceRepository(
      employeeCreatedAt: DateTime.utc(2026, 9, 1, 3),
    );
  });

  /// Worked on the 5th (normal), 6th (ended at 23:00, 2 flags), 9th (two
  /// sessions) and today the 17th (still running).
  void aMonth() {
    repository.months[october] = [
      attendanceSession(
        'a',
        year: 2026,
        month: 10,
        day: 5,
        minutes: 446,
        km: 12.345,
        visits: 2,
      ),
      attendanceSession(
        'b',
        year: 2026,
        month: 10,
        day: 6,
        startHour: 20,
        startMinute: 0,
        minutes: 180,
        status: 'auto_curfew',
        km: 5,
        visits: 1,
        flagged: 2,
      ),
      attendanceSession(
        'c',
        year: 2026,
        month: 10,
        day: 9,
        startHour: 8,
        startMinute: 0,
        minutes: 120,
        km: 3,
        visits: 1,
      ),
      attendanceSession(
        'd',
        year: 2026,
        month: 10,
        day: 9,
        startHour: 14,
        startMinute: 30,
        minutes: 60,
        km: 4,
        visits: 0,
      ),
      attendanceSession(
        'e',
        year: 2026,
        month: 10,
        day: 17,
        open: true,
        km: 1.5,
        visits: 0,
      ),
    ];
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    ValueChanged<String>? onViewRouteDay,
    VoidCallback? onBack,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: attendanceOverrides(repository),
        child: MaterialApp(
          theme: AppTheme.light,
          home: AdminAttendancePage(
            employeeId: 'e1',
            employeeName: 'Asha Patil',
            employeeCode: 'DA-101',
            onBack: onBack,
            onViewRouteDay: onViewRouteDay,
          ),
        ),
      ),
    );
    if (settle) await settleFrames(tester);
  }

  group('the screen', () {
    testWidgets('shows the employee, the month and the shared top bar', (
      tester,
    ) async {
      aMonth();
      await pumpPage(tester);

      expect(find.byType(AppTopBar), findsOneWidget);
      expect(find.text('Attendance & History'), findsOneWidget);
      expect(find.text('Asha Patil · DA-101'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('AP'), findsOneWidget);
    });

    testWidgets('back goes back', (tester) async {
      var backed = false;
      await pumpPage(tester, onBack: () => backed = true);

      await tester.tap(find.byKey(const Key('btn-attendance-back')));

      expect(backed, isTrue);
    });

    testWidgets(
      'has no payroll approval or payable-hours override (payroll is a non-goal)',
      (tester) async {
        aMonth();
        await pumpPage(tester);

        expect(find.textContaining('Approve'), findsNothing);
        expect(find.textContaining('Adjust'), findsNothing);
        expect(find.textContaining('ayable'), findsNothing);
        expect(find.textContaining('ayroll'), findsNothing);
        expect(find.byKey(const Key('btn-attendance-approve')), findsNothing);
      },
    );
  });

  group('the totals', () {
    testWidgets('are the months rows added up', (tester) async {
      aMonth();
      await pumpPage(tester);

      expect(find.byType(AdminAttendanceSummaryCard), findsOneWidget);
      // 5th 7h26 + 6th 3h + 9th 3h + 17th 1h56 so far = 15h 22m
      expect(find.text('4'), findsWidgets, reason: 'days worked');
      expect(find.text('15h 22m'), findsOneWidget);
      expect(find.text('Total hours'), findsOneWidget);
      expect(find.text('Days worked'), findsOneWidget);
      expect(find.text('Auto-ended'), findsWidgets);
    });

    testWidgets('a distance the server could not give shows a dash', (
      tester,
    ) async {
      repository.months[october] = [
        attendanceSession(
          'e',
          year: 2026,
          month: 10,
          day: 17,
          open: true,
          km: null,
        ),
      ];
      await pumpPage(tester);

      expect(find.text('—'), findsOneWidget);
    });
  });

  group('the days', () {
    testWidgets('each day says what it was', (tester) async {
      aMonth();
      await pumpPage(tester);

      expect(find.byType(AdminAttendanceDailyCard), findsNWidgets(17));
      // A normal day:
      expect(find.text('8:04 AM – 3:30 PM'), findsOneWidget);
      expect(find.text('7h 26m · 12.3 km · 2 visits'), findsOneWidget);
      // Ended at 23:00:
      expect(find.text('AUTO-ENDED'), findsOneWidget);
      expect(
        find.text('Duty ended automatically · 2 flagged points'),
        findsOneWidget,
      );
      // Two sessions:
      expect(find.text('2 SESSIONS'), findsOneWidget);
      expect(find.text('8:00 AM – 10:00 AM'), findsOneWidget);
      expect(find.text('2:30 PM – 3:30 PM'), findsOneWidget);
      // Still running:
      expect(find.byKey(const Key('attendance-in-progress')), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsOneWidget);
      expect(find.text('1h 56m so far · 1.5 km · 0 visits'), findsOneWidget);
    });

    testWidgets('absent days are dimmed and say so', (tester) async {
      aMonth();
      await pumpPage(tester);

      expect(find.text('No duty recorded'), findsWidgets);
      expect(find.text('OFF'), findsWidgets);
      expect(
        find.byKey(const Key('attendance-card-2026-10-07')),
        findsNothing,
        reason: 'an absent day is not a button',
      );
    });

    testWidgets('tapping a day with duty opens that days route, by date', (
      tester,
    ) async {
      aMonth();
      String? opened;
      await pumpPage(tester, onViewRouteDay: (day) => opened = day);

      final card = find.byKey(const Key('attendance-card-2026-10-05'));
      await tester.ensureVisible(card);
      await tester.pump();
      await tester.tap(card);

      expect(opened, '2026-10-05');
    });

    testWidgets('tapping an absent day does nothing', (tester) async {
      aMonth();
      String? opened;
      await pumpPage(tester, onViewRouteDay: (day) => opened = day);

      final absent = find.text('Wednesday, 7 October 2026');
      await tester.ensureVisible(absent);
      await tester.pump();
      await tester.tap(absent);

      expect(opened, isNull);
    });
  });

  group('filters', () {
    testWidgets('the chips count the days and narrow the list', (tester) async {
      aMonth();
      await pumpPage(tester);

      expect(find.byType(AdminAttendanceFilterChips), findsOneWidget);
      await tapChip(tester, 'attendance-filter-auto-ended');
      expect(find.byType(AdminAttendanceDailyCard), findsOneWidget);
      expect(find.text('AUTO-ENDED'), findsOneWidget);

      await tapChip(tester, 'attendance-filter-flags');
      expect(find.byType(AdminAttendanceDailyCard), findsOneWidget);

      await tapChip(tester, 'attendance-filter-absent');
      expect(find.byType(AdminAttendanceDailyCard), findsNWidgets(13));

      await tapChip(tester, 'attendance-filter-all');
      expect(find.byType(AdminAttendanceDailyCard), findsNWidgets(17));
    });

    testWidgets(
      'the banner names the days ended at 23:00 and filters to them',
      (tester) async {
        aMonth();
        await pumpPage(tester);

        expect(find.text('1 day ended automatically at 23:00'), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn-discrepancy-review')));
        await tester.pump();

        expect(find.byType(AdminAttendanceDailyCard), findsOneWidget);
      },
    );

    testWidgets('no banner when nothing ended automatically', (tester) async {
      repository.months[october] = [
        attendanceSession('a', year: 2026, month: 10, day: 5),
      ];
      await pumpPage(tester);

      expect(find.byKey(const Key('btn-discrepancy-review')), findsNothing);
    });

    testWidgets('filtering everything out says so and offers to clear', (
      tester,
    ) async {
      repository.months[october] = [
        attendanceSession('a', year: 2026, month: 10, day: 5),
      ];
      await pumpPage(tester);

      await tapChip(tester, 'attendance-filter-flags');
      expect(find.text('No results for these filters'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.text('No results for these filters'), findsNothing);
    });
  });

  group('states', () {
    testWidgets('loading is shown, not an empty month', (tester) async {
      repository.gate(october);
      await pumpPage(tester, settle: false);
      await tester.pump();

      expect(find.byKey(const Key('attendance-loading')), findsOneWidget);
      expect(find.text('No duty this month'), findsNothing);
      expect(find.byType(AdminAttendanceSummaryCard), findsNothing);

      repository.release(october);
      await settleFrames(tester);
      expect(find.byKey(const Key('attendance-loading')), findsNothing);
      expect(find.byType(AdminAttendanceSummaryCard), findsOneWidget);
    });

    testWidgets('a month with no sessions at all says so', (tester) async {
      repository.employeeCreatedAt = DateTime.utc(2026, 10, 17, 3);
      await pumpPage(tester);

      expect(find.text('No duty this month'), findsOneWidget);
    });

    testWidgets('a failed load is an error with Retry, then recovers', (
      tester,
    ) async {
      repository.error = const NetworkException();
      await pumpPage(tester);

      expect(find.byKey(const Key('attendance-error')), findsOneWidget);
      expect(find.text("Couldn't load the attendance"), findsOneWidget);
      expect(find.text('No duty this month'), findsNothing);

      repository.error = null;
      aMonth();
      await tester.tap(find.text('Retry'));
      await settleFrames(tester);

      expect(find.byKey(const Key('attendance-error')), findsNothing);
      expect(find.byType(AdminAttendanceSummaryCard), findsOneWidget);
    });

    testWidgets('a month cut at the cap says so', (tester) async {
      repository.truncated = true;
      aMonth();
      await pumpPage(tester);

      expect(find.byKey(const Key('attendance-truncated')), findsOneWidget);
    });

    testWidgets('pull to refresh reads the month again', (tester) async {
      aMonth();
      await pumpPage(tester);
      final calls = repository.calls.length;

      await tester.fling(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await settleFrames(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(repository.calls.length, greaterThan(calls));
    });
  });

  group('the month', () {
    testWidgets('previous and next move the month and load it', (tester) async {
      repository.months[istMonthStartUtc(2026, 9)] = [
        attendanceSession('s', year: 2026, month: 9, day: 15, km: 4),
      ];
      aMonth();
      await pumpPage(tester);

      await tester.tap(find.byKey(const Key('btn-prev-month')));
      await settleFrames(tester);
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('4.0 km'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-next-month')));
      await settleFrames(tester);
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('the month name is a label, not a button that does nothing', (
      tester,
    ) async {
      aMonth();
      await pumpPage(tester);

      expect(
        find.descendant(
          of: find.byType(InkWell),
          matching: find.text('October 2026'),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.arrow_drop_down_rounded), findsNothing);
    });
  });
}

/// Taps a filter chip, scrolling its row first if the chip is off screen.
Future<void> tapChip(WidgetTester tester, String key) async {
  final chip = find.byKey(Key(key));
  await tester.ensureVisible(chip);
  await tester.pump();
  await tester.tap(chip);
  await tester.pump();
}

/// Lets queued async work finish.
Future<void> settleFrames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}
