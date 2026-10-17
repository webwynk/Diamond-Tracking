import 'package:diamond_tracking/domain/entities/admin_duty_session.dart';
import 'package:diamond_tracking/domain/entities/attendance_month.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_attendance.dart';

/// Saturday 17 October 2026, 10:00 IST.
final DateTime _now = DateTime.utc(2026, 10, 17, 4, 30);

AttendanceMonth _build(
  List<AdminDutySession> sessions, {
  int month = 10,
  DateTime? now,
  DateTime? createdAt,
}) => AttendanceMonth.build(
  month: DateTime(2026, month),
  sessions: sessions,
  serverNow: now ?? _now,
  employeeCreatedAt: createdAt,
);

AttendanceDay _day(AttendanceMonth m, int day) =>
    m.days.firstWhere((d) => d.date.day == day);

void main() {
  group('the totals are the sums of the rows', () {
    test(
      'days worked, hours, km, visits, flagged points and auto-ended days',
      () {
        final month = _build([
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
          attendanceSession(
            'c',
            year: 2026,
            month: 10,
            day: 7,
            minutes: 61,
            km: 0.25,
            visits: 0,
          ),
        ]);

        final s = month.summary;
        expect(s.daysWorked, 3);
        expect(s.totalDuration, const Duration(minutes: 480 + 90 + 61));
        expect(s.distanceKm, 12.75);
        expect(s.visitsCount, 4);
        expect(s.flaggedPoints, 4);
        expect(s.autoEndedDays, 1);
      },
    );

    test('the month total equals the sum of the days shown, to the second', () {
      final month = _build([
        attendanceSession(
          'a',
          year: 2026,
          month: 10,
          day: 2,
          minutes: 59,
          km: 1.111,
        ),
        attendanceSession(
          'b',
          year: 2026,
          month: 10,
          day: 3,
          minutes: 59,
          km: 2.222,
        ),
        attendanceSession(
          'c',
          year: 2026,
          month: 10,
          day: 4,
          minutes: 59,
          km: 3.333,
        ),
      ]);

      final worked = month.days.where((d) => !d.isAbsent);
      expect(
        month.summary.totalDuration,
        worked.fold(Duration.zero, (t, d) => t + d.duration),
      );
      expect(month.summary.distanceKm, closeTo(6.666, 1e-9));
      expect(month.summary.totalDuration, const Duration(minutes: 177));
    });

    test('a day with several sessions sums them', () {
      final month = _build([
        attendanceSession(
          'a',
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
          'b',
          year: 2026,
          month: 10,
          day: 9,
          startHour: 14,
          startMinute: 0,
          minutes: 90,
          km: 4.5,
          visits: 2,
          flagged: 1,
        ),
      ]);

      final day = _day(month, 9);
      expect(day.sessions.map((s) => s.id), ['a', 'b']);
      expect(day.duration, const Duration(minutes: 210));
      expect(day.distanceKm, 7.5);
      expect(day.visitsCount, 3);
      expect(day.flaggedPoints, 1);
      expect(month.summary.daysWorked, 1, reason: 'one day, two sessions');
    });

    test(
      'sessions come back oldest first within a day, whatever order they arrive',
      () {
        final month = _build([
          attendanceSession(
            'late',
            year: 2026,
            month: 10,
            day: 9,
            startHour: 14,
          ),
          attendanceSession(
            'early',
            year: 2026,
            month: 10,
            day: 9,
            startHour: 8,
          ),
        ]);

        expect(_day(month, 9).sessions.map((s) => s.id), ['early', 'late']);
      },
    );
  });

  group('a session still running (PRD: never shown as zero hours)', () {
    test('runs to the SERVER clock', () {
      // Started 08:04 IST; the server says it is now 10:00 IST.
      final month = _build([
        attendanceSession(
          'open',
          year: 2026,
          month: 10,
          day: 17,
          open: true,
          km: 2,
        ),
      ]);

      final day = _day(month, 17);
      expect(day.hasOpenSession, isTrue);
      expect(day.duration, const Duration(hours: 1, minutes: 56));
      expect(
        month.summary.totalDuration,
        const Duration(hours: 1, minutes: 56),
      );
    });

    test(
      'its unknown distance makes the day and the month unknown, never a smaller total',
      () {
        final month = _build([
          attendanceSession('done', year: 2026, month: 10, day: 16, km: 10),
          attendanceSession(
            'open',
            year: 2026,
            month: 10,
            day: 17,
            open: true,
            km: null,
          ),
        ]);

        expect(_day(month, 16).distanceKm, 10);
        expect(_day(month, 17).distanceKm, isNull);
        expect(month.summary.distanceKm, isNull);
      },
    );

    test(
      'a start slightly ahead of the server clock lasts zero, not negative',
      () {
        final month = _build([
          attendanceSession(
            'open',
            year: 2026,
            month: 10,
            day: 17,
            startHour: 10,
            startMinute: 30,
            open: true,
          ),
        ]);

        expect(_day(month, 17).duration, Duration.zero);
      },
    );
  });

  group('which IST day a session belongs to', () {
    test(
      'by the IST day it started on: 18:29 UTC is still the day before in IST',
      () {
        // 23:59 IST on the 5th = 18:29 UTC on the 5th; 00:00 IST on the 6th = 18:30 UTC.
        final lateOnFifth = AdminDutySession(
          id: 'a',
          status: 'completed',
          startedAt: DateTime.utc(2026, 10, 5, 18, 29),
          endedAt: DateTime.utc(2026, 10, 5, 18, 29, 30),
          distanceKm: 1,
        );
        final earlyOnSixth = AdminDutySession(
          id: 'b',
          status: 'completed',
          startedAt: DateTime.utc(2026, 10, 5, 18, 30),
          endedAt: DateTime.utc(2026, 10, 5, 19),
          distanceKm: 1,
        );

        final month = _build([lateOnFifth, earlyOnSixth]);

        expect(_day(month, 5).sessions.single.id, 'a');
        expect(_day(month, 6).sessions.single.id, 'b');
      },
    );

    test('a session outside the month is ignored', () {
      final month = _build([
        attendanceSession('sep', year: 2026, month: 9, day: 30),
        attendanceSession('nov', year: 2026, month: 11, day: 1),
        attendanceSession('in', year: 2026, month: 10, day: 10),
      ]);

      expect(month.summary.daysWorked, 1);
      expect(_day(month, 10).sessions.single.id, 'in');
    });

    test('the day id is the date the route view opens on', () {
      final month = _build([
        attendanceSession('a', year: 2026, month: 10, day: 5),
      ]);

      expect(_day(month, 5).id, '2026-10-05');
    });
  });

  group('absent days', () {
    test(
      'are the past days with no duty; today and the future are not absent',
      () {
        // Now is the 17th. Worked on the 3rd and the 10th only.
        final month = _build([
          attendanceSession('a', year: 2026, month: 10, day: 3),
          attendanceSession('b', year: 2026, month: 10, day: 10),
        ]);

        final absent = month.days
            .where((d) => d.isAbsent)
            .map((d) => d.date.day);
        expect(
          absent.toSet(),
          {for (var d = 1; d <= 16; d++) d}.difference({3, 10}),
        );
        expect(month.summary.absentDays, 14);
        expect(month.days.any((d) => d.date.day >= 17), isFalse);
      },
    );

    test('today counts once it has duty, with the day not yet over', () {
      final month = _build([
        attendanceSession('t', year: 2026, month: 10, day: 17, open: true),
      ]);

      expect(_day(month, 17).isAbsent, isFalse);
      expect(month.days.where((d) => d.date.day == 17), hasLength(1));
    });

    test('nothing before the employee first day is absent', () {
      // Created on the 12th (IST), so the 1st to the 11th are not absences.
      final month = _build(const [], createdAt: DateTime.utc(2026, 10, 12, 3));

      final days = month.days.map((d) => d.date.day).toList();
      expect(days.first, 16);
      expect(days.last, 12);
      expect(month.summary.absentDays, 5);
    });

    test('the first day itself counts when there was no duty on it', () {
      final month = _build(const [], createdAt: DateTime.utc(2026, 10, 16, 3));

      expect(month.days.map((d) => d.date.day), [16]);
    });

    test('created today or later: no absences yet', () {
      final month = _build(const [], createdAt: DateTime.utc(2026, 10, 17, 3));

      expect(month.days, isEmpty);
      expect(month.summary.absentDays, 0);
    });

    test(
      'an employee created in a later month has nothing to show for an earlier one',
      () {
        final month = _build(
          const [],
          month: 9,
          createdAt: DateTime.utc(2026, 10, 1, 3),
        );

        expect(month.days, isEmpty);
      },
    );

    test(
      'a finished month counts every day without duty, its last day included',
      () {
        final month = _build([
          attendanceSession('a', year: 2026, month: 9, day: 15),
        ], month: 9);

        expect(month.summary.daysWorked, 1);
        expect(month.summary.absentDays, 29);
        expect(month.days.first.date.day, 30);
      },
    );

    test(
      'an unknown first day counts from the 1st rather than hiding absences',
      () {
        final month = _build(const []);

        expect(month.summary.absentDays, 16);
      },
    );

    test(
      'is judged on the server clock: just after midnight IST it is a new day',
      () {
        // 00:10 IST on the 18th = 18:40 UTC on the 17th. The 17th is now over.
        final month = _build(const [], now: DateTime.utc(2026, 10, 17, 18, 40));

        expect(month.days.first.date.day, 17);
        expect(month.days.first.isAbsent, isTrue);
      },
    );
  });

  group('ordering and flags', () {
    test('days are newest first, absent ones among them', () {
      final month = _build([
        attendanceSession('a', year: 2026, month: 10, day: 3),
        attendanceSession('b', year: 2026, month: 10, day: 14),
      ]);

      final days = month.days.map((d) => d.date.day).toList();
      expect(days, [...days]..sort((a, b) => b.compareTo(a)));
      expect(days.first, 16);
    });

    test('an automatic end and a flag are noticed per day', () {
      final month = _build([
        attendanceSession(
          'a',
          year: 2026,
          month: 10,
          day: 6,
          status: 'auto_curfew',
          flagged: 2,
        ),
        attendanceSession(
          'b',
          year: 2026,
          month: 10,
          day: 7,
          status: 'blocked',
        ),
      ]);

      expect(_day(month, 6).endedAutomatically, isTrue);
      expect(_day(month, 6).hasFlag, isTrue);
      expect(_day(month, 7).endedAutomatically, isFalse);
      expect(month.summary.autoEndedDays, 1);
      expect(month.summary.daysWorked, 2);
    });

    test('two automatic ends on one day count that day once', () {
      final month = _build([
        attendanceSession(
          'a',
          year: 2026,
          month: 10,
          day: 6,
          startHour: 8,
          minutes: 60,
          status: 'completed',
        ),
        attendanceSession(
          'b',
          year: 2026,
          month: 10,
          day: 6,
          startHour: 20,
          minutes: 180,
          status: 'auto_curfew',
        ),
      ]);

      expect(month.summary.autoEndedDays, 1);
    });
  });
}
