import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/controllers/admin_attendance_controller.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/controllers/admin_attendance_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_attendance.dart';

void main() {
  late FakeAttendanceRepository repository;
  final october = istMonthStartUtc(2026, 10);
  final september = istMonthStartUtc(2026, 9);

  setUp(() {
    // Started on 1 September 2026 (IST).
    repository = FakeAttendanceRepository(
      employeeCreatedAt: DateTime.utc(2026, 9, 1, 3),
    );
  });

  ProviderContainer open() {
    final container = ProviderContainer(
      overrides: attendanceOverrides(repository),
    );
    addTearDown(container.dispose);
    container.listen(adminAttendanceControllerProvider('e1'), (_, _) {});
    return container;
  }

  AdminAttendanceState stateOf(ProviderContainer c) =>
      c.read(adminAttendanceControllerProvider('e1'));

  AdminAttendanceNotifier notifierOf(ProviderContainer c) =>
      c.read(adminAttendanceControllerProvider('e1').notifier);

  AdminDailyAttendanceItem item(ProviderContainer c, String id) =>
      stateOf(c).dailyLogs.firstWhere((d) => d.id == id);

  group('opening', () {
    test('starts on this IST month, loading, with nothing invented', () async {
      final container = open();

      final before = stateOf(container);
      expect(before.load, AttendanceLoad.loading);
      expect(before.selectedMonth, 'October 2026');
      expect(before.dailyLogs, isEmpty);
      expect(before.metrics.daysWorked, 0);

      await pumpEventQueue();

      final call = repository.calls.single;
      expect(call.employeeId, 'e1');
      expect(call.monthStartUtc, october, reason: '00:00 IST on 1 Oct');
      expect(call.monthEndUtc, istMonthStartUtc(2026, 11));
      expect(stateOf(container).load, AttendanceLoad.loaded);
    });

    test(
      'just after midnight IST on the 1st it is already the new month',
      () async {
        // 00:10 IST on 1 November = 18:40 UTC on 31 October.
        final container = ProviderContainer(
          overrides: attendanceOverrides(
            repository,
            now: DateTime.utc(2026, 10, 31, 18, 40),
          ),
        );
        addTearDown(container.dispose);
        container.listen(adminAttendanceControllerProvider('e1'), (_, _) {});

        expect(stateOf(container).selectedMonth, 'November 2026');
        await pumpEventQueue();
      },
    );
  });

  group('a day card says it in words', () {
    test('a normal day', () async {
      repository.months[october] = [
        attendanceSession('a', year: 2026, month: 10, day: 5),
      ];
      final container = open();
      await pumpEventQueue();

      final day = item(container, '2026-10-05');
      expect(day.dayNumber, '5');
      expect(day.dayOfWeek, 'Mon');
      expect(day.dateLabel, 'Mon, 5 Oct');
      expect(day.statusType, AdminDailyStatusType.normal);
      expect(day.sessions.single.timeRange, '8:04 AM – 3:30 PM');
      expect(day.statsText, '7h 26m · 12.3 km · 2 visits');
      expect(day.durationText, '7h 26m');
      expect(day.distanceText, '12.3 km');
      expect(day.alertNote, isNull);
      expect(day.hasChevron, isTrue);
      expect(day.isInProgress, isFalse);
    });

    test('one visit is singular', () async {
      repository.months[october] = [
        attendanceSession('a', year: 2026, month: 10, day: 5, visits: 1),
      ];
      final container = open();
      await pumpEventQueue();

      expect(item(container, '2026-10-05').statsText, endsWith('1 visit'));
    });

    test(
      'a day ended at 23:00 is labelled "Duty ended automatically"',
      () async {
        repository.months[october] = [
          attendanceSession(
            'a',
            year: 2026,
            month: 10,
            day: 6,
            status: 'auto_curfew',
            flagged: 2,
          ),
        ];
        final container = open();
        await pumpEventQueue();

        final day = item(container, '2026-10-06');
        expect(day.statusType, AdminDailyStatusType.autoEnded);
        expect(day.isAutoEnded, isTrue);
        expect(day.alertNote, 'Duty ended automatically · 2 flagged points');
        expect(day.hasFlag, isTrue);
      },
    );

    test('a day with several sessions lists each one', () async {
      repository.months[october] = [
        attendanceSession(
          'a',
          year: 2026,
          month: 10,
          day: 9,
          startHour: 8,
          startMinute: 0,
          minutes: 120,
        ),
        attendanceSession(
          'b',
          year: 2026,
          month: 10,
          day: 9,
          startHour: 14,
          startMinute: 30,
          minutes: 60,
        ),
      ];
      final container = open();
      await pumpEventQueue();

      final day = item(container, '2026-10-09');
      expect(day.statusType, AdminDailyStatusType.multiSession);
      expect(day.sessions.map((s) => s.timeRange), [
        '8:00 AM – 10:00 AM',
        '2:30 PM – 3:30 PM',
      ]);
      expect(day.durationText, '3h 0m');
    });

    test(
      'a session still running is in progress, hours so far, never zero',
      () async {
        repository.months[october] = [
          attendanceSession(
            'a',
            year: 2026,
            month: 10,
            day: 17,
            open: true,
            km: null,
          ),
        ];
        final container = open();
        await pumpEventQueue();

        final day = item(container, '2026-10-17');
        expect(day.isInProgress, isTrue);
        expect(day.sessions.single.timeRange, '8:04 AM – now');
        expect(day.durationText, '1h 56m so far');
        expect(day.distanceText, '— km');
        expect(day.statsText, '1h 56m so far · — km · 2 visits');
      },
    );

    test('an absent day names the date and cannot be opened', () async {
      final container = open();
      await pumpEventQueue();

      final day = item(container, '2026-10-07');
      expect(day.isAbsent, isTrue);
      expect(day.hasChevron, isFalse);
      expect(day.sessions, isEmpty);
      expect(day.statsText, 'Wednesday, 7 October 2026');
    });
  });

  group('the month totals in words', () {
    test('are the summed rows', () async {
      repository.months[october] = [
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
          flagged: 4,
          status: 'auto_curfew',
        ),
      ];
      final container = open();
      await pumpEventQueue();

      final m = stateOf(container).metrics;
      expect(m.daysWorked, 2);
      expect(m.totalHoursText, '9h 30m');
      expect(m.distanceKm, '12.5 km');
      expect(m.visitsCount, 4);
      expect(m.autoEndedCount, 1);
      expect(m.flagsCount, 4);
    });

    test(
      'a distance the server could not give shows a dash, not a smaller total',
      () async {
        repository.months[october] = [
          attendanceSession('a', year: 2026, month: 10, day: 5, km: 10),
          attendanceSession(
            'b',
            year: 2026,
            month: 10,
            day: 17,
            open: true,
            km: null,
          ),
        ];
        final container = open();
        await pumpEventQueue();

        expect(stateOf(container).metrics.distanceKm, '—');
      },
    );

    test(
      'an empty month is zeros after a real load, with every past day absent',
      () async {
        final container = open();
        await pumpEventQueue();

        expect(stateOf(container).load, AttendanceLoad.loaded);
        expect(stateOf(container).metrics.daysWorked, 0);
        expect(stateOf(container).absentCount, 16);
      },
    );
  });

  group('filters', () {
    test('narrow the days and keep their counts', () async {
      repository.months[october] = [
        attendanceSession('a', year: 2026, month: 10, day: 5),
        attendanceSession(
          'b',
          year: 2026,
          month: 10,
          day: 6,
          status: 'auto_curfew',
        ),
        attendanceSession('c', year: 2026, month: 10, day: 7, flagged: 1),
      ];
      final container = open();
      await pumpEventQueue();
      final notifier = notifierOf(container);

      expect(stateOf(container).dailyLogs, hasLength(16));
      expect(stateOf(container).autoEndedLogCount, 1);
      expect(stateOf(container).flaggedLogCount, 1);
      expect(stateOf(container).absentCount, 13);

      notifier.setFilter(AdminAttendanceFilter.autoEnded);
      expect(stateOf(container).filteredDailyLogs.map((d) => d.id), [
        '2026-10-06',
      ]);

      notifier.setFilter(AdminAttendanceFilter.withFlags);
      expect(stateOf(container).filteredDailyLogs.map((d) => d.id), [
        '2026-10-07',
      ]);

      notifier.setFilter(AdminAttendanceFilter.absent);
      expect(stateOf(container).filteredDailyLogs, hasLength(13));
      expect(
        stateOf(container).filteredDailyLogs.every((d) => d.isAbsent),
        isTrue,
      );

      notifier.setFilter(AdminAttendanceFilter.allDays);
      expect(stateOf(container).filteredDailyLogs, hasLength(16));
    });

    test('are kept when the month changes', () async {
      final container = open();
      await pumpEventQueue();
      notifierOf(container).setFilter(AdminAttendanceFilter.absent);

      notifierOf(container).previousMonth();
      await pumpEventQueue();

      expect(stateOf(container).selectedFilter, AdminAttendanceFilter.absent);
    });
  });

  group('the month picker', () {
    test('cannot go past the current month', () async {
      final container = open();
      await pumpEventQueue();

      notifierOf(container).nextMonth();
      await pumpEventQueue();

      expect(stateOf(container).selectedMonth, 'October 2026');
      expect(repository.calls, hasLength(1));
    });

    test('goes back a month, loads it, and comes forward again', () async {
      repository.months[september] = [
        attendanceSession('s', year: 2026, month: 9, day: 15, km: 4),
      ];
      final container = open();
      await pumpEventQueue();

      notifierOf(container).previousMonth();
      expect(stateOf(container).load, AttendanceLoad.loading);
      expect(stateOf(container).selectedMonth, 'September 2026');
      expect(stateOf(container).dailyLogs, isEmpty, reason: 'no leftovers');
      await pumpEventQueue();

      expect(repository.calls.last.monthStartUtc, september);
      expect(stateOf(container).metrics.daysWorked, 1);
      expect(
        stateOf(container).absentCount,
        29,
        reason: 'from 1 Sep, a finished month',
      );

      notifierOf(container).nextMonth();
      await pumpEventQueue();
      expect(stateOf(container).selectedMonth, 'October 2026');
    });

    test('stops at the month the employee started', () async {
      final container = open();
      await pumpEventQueue();
      notifierOf(container).previousMonth(); // September: the first month
      await pumpEventQueue();
      final calls = repository.calls.length;

      notifierOf(container).previousMonth(); // August: before the first day
      await pumpEventQueue();

      expect(stateOf(container).selectedMonth, 'September 2026');
      expect(repository.calls.length, calls);
    });

    test('with the first day unknown it stops two years back', () async {
      repository.employeeCreatedAt = null;
      final container = open();
      await pumpEventQueue();

      for (var i = 0; i < 30; i++) {
        notifierOf(container).previousMonth();
        await pumpEventQueue();
      }

      expect(stateOf(container).selectedMonth, 'October 2024');
    });
  });

  group('failure and overtaken loads', () {
    test('a failed load is an error that reload recovers from', () async {
      repository.error = const NetworkException();
      final container = open();
      await pumpEventQueue();

      expect(stateOf(container).load, AttendanceLoad.failed);
      expect(stateOf(container).errorMessage, isNotNull);
      expect(stateOf(container).dailyLogs, isEmpty);

      repository.error = null;
      repository.months[october] = [
        attendanceSession('a', year: 2026, month: 10, day: 5),
      ];
      await notifierOf(container).reload();

      expect(stateOf(container).load, AttendanceLoad.loaded);
      expect(stateOf(container).errorMessage, isNull);
      expect(stateOf(container).metrics.daysWorked, 1);
    });

    test('an unexpected failure gets a plain message, not its text', () async {
      repository.error = const FormatException('secret details');
      final container = open();
      await pumpEventQueue();

      expect(stateOf(container).load, AttendanceLoad.failed);
      expect(stateOf(container).errorMessage, isNot(contains('secret')));
    });

    test(
      'a slow answer for an old month never replaces the month on screen',
      () async {
        repository.gate(october);
        repository.months[october] = [
          attendanceSession('o', year: 2026, month: 10, day: 5, km: 99),
        ];
        repository.months[september] = [
          attendanceSession('s', year: 2026, month: 9, day: 15, km: 4),
        ];
        final container = open();
        await pumpEventQueue();
        expect(stateOf(container).load, AttendanceLoad.loading);

        notifierOf(container).previousMonth();
        await pumpEventQueue();
        expect(stateOf(container).metrics.distanceKm, '4.0 km');

        repository.release(october);
        await pumpEventQueue();

        expect(stateOf(container).selectedMonth, 'September 2026');
        expect(stateOf(container).metrics.distanceKm, '4.0 km');
      },
    );

    test('says when the month was cut at the safety cap', () async {
      repository.truncated = true;
      final container = open();
      await pumpEventQueue();

      expect(stateOf(container).truncated, isTrue);
    });
  });
}
