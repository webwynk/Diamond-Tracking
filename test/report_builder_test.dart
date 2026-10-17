import 'package:diamond_tracking/domain/entities/admin_duty_session.dart';
import 'package:diamond_tracking/domain/entities/attendance_month.dart';
import 'package:diamond_tracking/domain/entities/report_builder.dart';
import 'package:diamond_tracking/domain/entities/report_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_attendance.dart';

/// Saturday 17 October 2026, 10:00 IST.
final DateTime _now = DateTime.utc(2026, 10, 17, 4, 30);

final DateTime _longAgo = DateTime.utc(2026, 1, 1);

ReportEmployee _emp(
  String id,
  String name, {
  bool active = true,
  DateTime? createdAt,
}) => ReportEmployee(
  id: id,
  name: name,
  code: 'DA-$id',
  isActive: active,
  createdAt: createdAt ?? _longAgo,
);

AdminDutySession _s(
  String id,
  String employee,
  int day, {
  int minutes = 480,
  double? km = 10,
  int visits = 1,
  int flagged = 0,
  String status = 'completed',
  bool open = false,
  int startHour = 8,
}) => attendanceSession(
  id,
  year: 2026,
  month: 10,
  day: day,
  minutes: minutes,
  km: km,
  visits: visits,
  flagged: flagged,
  status: status,
  open: open,
  startHour: startHour,
  employeeId: employee,
);

ReportSource _source(
  List<AdminDutySession> sessions,
  List<ReportEmployee> employees, {
  bool truncated = false,
}) => ReportSource(
  sessions: sessions,
  employees: employees,
  serverNow: _now,
  truncated: truncated,
);

void main() {
  final asha = _emp('a', 'Asha');
  final ravi = _emp('r', 'Ravi');
  final meena = _emp('m', 'Meena');

  group('the team summary reconciles with the attendance screen', () {
    test('each row equals the attendance month of that employee', () {
      final sessions = [
        _s('1', 'a', 5, minutes: 480, km: 10.5, visits: 3),
        _s('2', 'a', 6, minutes: 61, km: 0.25, status: 'auto_curfew'),
        _s('3', 'r', 5, minutes: 300, km: 4, flagged: 2),
        _s('4', 'r', 12, minutes: 200, km: 3.5),
      ];
      final report = ReportBuilder.team(
        _source(sessions, [asha, ravi, meena]),
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 31),
      );

      for (final row in report.rows) {
        final month = AttendanceMonth.build(
          month: DateTime(2026, 10),
          sessions: sessions
              .where((s) => s.employeeId == row.employee.id)
              .toList(),
          serverNow: _now,
          employeeCreatedAt: row.employee.createdAt,
        );
        expect(row.summary.daysWorked, month.summary.daysWorked);
        expect(row.summary.totalDuration, month.summary.totalDuration);
        expect(row.summary.distanceKm, month.summary.distanceKm);
        expect(row.summary.visitsCount, month.summary.visitsCount);
        expect(row.summary.autoEndedDays, month.summary.autoEndedDays);
        expect(row.summary.flaggedPoints, month.summary.flaggedPoints);
        expect(row.summary.absentDays, month.summary.absentDays);
      }
    });

    test('the totals are the sums of the rows, rows sorted by name', () {
      final report = ReportBuilder.team(
        _source(
          [_s('1', 'r', 5, km: 4.5), _s('2', 'a', 6, km: 1.25)],
          [ravi, asha, meena],
        ),
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 31),
      );

      expect(report.rows.map((r) => r.employee.name), [
        'Asha',
        'Meena',
        'Ravi',
      ]);
      expect(report.totals.daysWorked, 2);
      expect(report.totals.totalDuration, const Duration(hours: 16));
      expect(report.totals.distanceKm, 5.75);
      expect(report.totals.visitsCount, 2);
      expect(
        report.totals.absentDays,
        report.rows.fold<int>(0, (sum, r) => sum + r.summary.absentDays),
      );
    });

    test('an unknown distance makes the total unknown, never smaller', () {
      final report = ReportBuilder.team(
        _source(
          [_s('1', 'a', 5, km: 4), _s('2', 'r', 5, km: null)],
          [asha, ravi],
        ),
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 31),
      );

      expect(report.totals.distanceKm, isNull);
    });

    test('a session from another period is ignored', () {
      final report = ReportBuilder.team(
        _source([_s('1', 'a', 5)], [asha]),
        from: DateTime(2026, 10, 10),
        to: DateTime(2026, 10, 16),
      );

      expect(report.rows.single.summary.daysWorked, 0);
      expect(report.rows.single.summary.absentDays, 7);
    });

    test(
      'a blocked employee appears only if they worked, with no absences',
      () {
        final blocked = _emp('b', 'Bala', active: false);
        final idle = _emp('i', 'Idle', active: false);
        final report = ReportBuilder.team(
          _source([_s('1', 'b', 5)], [asha, blocked, idle]),
          from: DateTime(2026, 10),
          to: DateTime(2026, 10, 16),
        );

        expect(report.rows.map((r) => r.employee.name), ['Asha', 'Bala']);
        expect(report.rows.last.summary.daysWorked, 1);
        expect(report.rows.last.summary.absentDays, 0);
      },
    );
  });

  group('the employee summary', () {
    test('equals the attendance period of that employee, day for day', () {
      final sessions = [
        _s('1', 'a', 5, km: 10),
        _s('2', 'a', 5, minutes: 30, startHour: 20, km: 1),
        _s('3', 'r', 6),
        _s('4', 'a', 17, open: true, km: 2.5),
      ];
      final report = ReportBuilder.employee(
        _source(sessions, [asha, ravi]),
        employee: asha,
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 17),
      );

      final fifth = report.period.days.firstWhere((d) => d.date.day == 5);
      expect(fifth.sessions.length, 2);
      expect(fifth.duration, const Duration(hours: 8, minutes: 30));
      expect(fifth.distanceKm, 11);
      // The other employee's day is not hers.
      expect(
        report.period.days.firstWhere((d) => d.date.day == 6).isAbsent,
        isTrue,
      );
      expect(report.period.summary.daysWorked, 2);
      // A day that is still open ends at the server's clock.
      final today = report.period.days.firstWhere((d) => d.date.day == 17);
      expect(today.hasOpenSession, isTrue);
      expect(today.duration, const Duration(hours: 1, minutes: 56));
    });

    test('today is never absent, a blocked account has no absent days', () {
      final blocked = _emp('b', 'Bala', active: false);
      final active = ReportBuilder.employee(
        _source(const [], [asha]),
        employee: asha,
        from: DateTime(2026, 10, 15),
        to: DateTime(2026, 10, 17),
      );
      final off = ReportBuilder.employee(
        _source(const [], [blocked]),
        employee: blocked,
        from: DateTime(2026, 10, 15),
        to: DateTime(2026, 10, 17),
      );

      expect(active.period.summary.absentDays, 2);
      expect(off.period.summary.absentDays, 0);
      expect(off.period.days, isEmpty);
    });
  });

  group('the daily detail', () {
    test('lists every session of the day, by employee then start', () {
      final report = ReportBuilder.daily(
        _source(
          [
            _s('1', 'r', 5, startHour: 9),
            _s('2', 'a', 5, startHour: 14, minutes: 60),
            _s('3', 'a', 5, startHour: 8, minutes: 120, km: 3),
            _s('4', 'a', 6),
          ],
          [asha, ravi, meena],
        ),
        day: DateTime(2026, 10, 5),
      );

      expect(report.rows.map((r) => r.session.id), ['3', '2', '1']);
      expect(report.employeesOnDuty, 2);
      expect(report.totalDuration, const Duration(hours: 11));
      expect(report.distanceKm, 23);
      expect(report.visits, 3);
    });

    test(
      'absent are active employees already on the team, once the day is over',
      () {
        final newcomer = _emp(
          'n',
          'Newbie',
          createdAt: DateTime.utc(2026, 10, 8),
        );
        final blocked = _emp('b', 'Bala', active: false);
        final report = ReportBuilder.daily(
          _source([_s('1', 'a', 5)], [asha, ravi, meena, newcomer, blocked]),
          day: DateTime(2026, 10, 5),
        );

        expect(report.absentKnown, isTrue);
        expect(report.absent.map((e) => e.name), ['Meena', 'Ravi']);
      },
    );

    test(
      'today has no absent list, and open sessions count as in progress',
      () {
        final report = ReportBuilder.daily(
          _source([_s('1', 'a', 17, open: true, km: null)], [asha, ravi]),
          day: DateTime(2026, 10, 17),
        );

        expect(report.absentKnown, isFalse);
        expect(report.absent, isEmpty);
        expect(report.inProgress, 1);
        expect(report.distanceKm, isNull);
        expect(report.totalDuration, const Duration(hours: 1, minutes: 56));
      },
    );

    test('counts auto-ended sessions and flagged points', () {
      final report = ReportBuilder.daily(
        _source(
          [
            _s('1', 'a', 5, status: 'auto_curfew', flagged: 3),
            _s('2', 'r', 5, flagged: 1),
          ],
          [asha, ravi],
        ),
        day: DateTime(2026, 10, 5),
      );

      expect(report.autoEnded, 1);
      expect(report.flaggedPoints, 4);
    });

    test('a session of someone not in the roster is shown, not dropped', () {
      final report = ReportBuilder.daily(
        _source([_s('1', 'ghost', 5)], [asha]),
        day: DateTime(2026, 10, 5),
      );

      expect(report.rows.single.employee.name, 'Unknown employee');
    });

    test('passes the truncation flag on', () {
      final report = ReportBuilder.daily(
        _source(const [], [asha], truncated: true),
        day: DateTime(2026, 10, 5),
      );

      expect(report.truncated, isTrue);
    });
  });
}
