import 'dart:convert';

import 'package:diamond_tracking/core/reports/report_pdf_renderer.dart';
import 'package:diamond_tracking/core/reports/report_pdf_style.dart';
import 'package:diamond_tracking/domain/entities/admin_duty_session.dart';
import 'package:diamond_tracking/domain/entities/report_builder.dart';
import 'package:diamond_tracking/domain/entities/report_data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_attendance.dart';
import 'support/fake_report.dart';

/// Saturday 17 October 2026, 10:00 IST.
final DateTime _now = DateTime.utc(2026, 10, 17, 4, 30);

ReportEmployee _emp(String id, String name, {bool active = true}) =>
    ReportEmployee(
      id: id,
      name: name,
      code: 'DA-$id',
      isActive: active,
      createdAt: DateTime.utc(2026, 1, 1),
    );

ReportSource _source(
  List<ReportEmployee> employees, [
  List<AdminDutySession> sessions = const [],
]) => ReportSource(sessions: sessions, employees: employees, serverNow: _now);

AdminDutySession _s(
  String id,
  int day,
  String employee, {
  int minutes = 480,
  double? km = 10,
  String status = 'completed',
  int flagged = 0,
  bool open = false,
}) => attendanceSession(
  id,
  year: 2026,
  month: 10,
  day: day,
  employeeId: employee,
  minutes: minutes,
  km: km,
  status: status,
  flagged: flagged,
  open: open,
);

ReportPdfRenderer _renderer() =>
    ReportPdfRenderer(fonts: standardReportFonts(), compress: false);

/// The text drawn on the pages: every string the PDF shows, in order.
String _text(Uint8List pdf) {
  final raw = latin1.decode(pdf);
  final buffer = StringBuffer();
  for (final match in RegExp(r'\(((?:\\.|[^\\)])*)\)').allMatches(raw)) {
    buffer
      ..write(match.group(1)!.replaceAll(r'\(', '(').replaceAll(r'\)', ')'))
      ..write(' ');
  }
  return buffer.toString();
}

int _pages(Uint8List pdf) =>
    RegExp(r'/Type\s*/Page(?!s)').allMatches(latin1.decode(pdf)).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final asha = _emp('a', 'Asha Patel');
  final ravi = _emp('r', 'Ravi Kumar');
  final meena = _emp('m', 'Meena Rao');
  final team = [asha, ravi, meena];

  group('the file name', () {
    test('names the report and the dates', () {
      final report = ReportBuilder.team(
        _source(team),
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 17),
      );
      expect(
        ReportPdfRenderer.fileName(report),
        'DiamondAgritech_TeamSummary_2026-10-01_to_2026-10-17.pdf',
      );
    });

    test('a daily report has one date, an employee report the code', () {
      final daily = ReportBuilder.daily(
        _source(team),
        day: DateTime(2026, 10, 5),
      );
      final one = ReportBuilder.employee(
        _source(team),
        employee: asha,
        from: DateTime(2026, 9, 3),
        to: DateTime(2026, 10, 17),
      );
      expect(
        ReportPdfRenderer.fileName(daily),
        'DiamondAgritech_DailyDetail_2026-10-05.pdf',
      );
      expect(
        ReportPdfRenderer.fileName(one),
        'DiamondAgritech_EmployeeSummary_DA-a_2026-09-03_to_2026-10-17.pdf',
      );
    });

    test('is safe on any file system, whatever the employee code holds', () {
      const odd = ReportEmployee(id: 'x', name: 'N', code: r'A/B:C?*"<>|');
      final report = ReportBuilder.employee(
        _source([odd]),
        employee: odd,
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 2),
      );
      expect(
        ReportPdfRenderer.fileName(report),
        isNot(matches(RegExp(r'[\\/:*?"<>|]'))),
      );
    });
  });

  group('team summary', () {
    test('is a valid PDF with the figures of the report', () async {
      final report = ReportBuilder.team(
        _source(team, [
          _s('1', 5, 'a', km: 10.5),
          _s(
            '2',
            6,
            'a',
            minutes: 61,
            km: 0.25,
            status: 'auto_curfew',
            flagged: 4,
          ),
          _s('3', 5, 'r', minutes: 300, km: 4),
        ]),
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 17),
      );

      final pdf = await _renderer().render(report, generatedBy: 'Admin One');
      final text = _text(pdf);

      expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
      expect(text, contains('Team Attendance Summary'));
      expect(
        text,
        contains('Generated 17 Oct 2026, 10:00 AM IST by Admin One'),
      );
      expect(text, contains('Asha Patel'));
      expect(text, contains('Ravi Kumar'));
      expect(text, contains('Meena Rao'));
      // Asha: 2 days, 9h 1m, 10.8 km (10.75), auto-ended 1, flagged 4.
      expect(text, contains('9h 1m'));
      expect(text, contains('Total'));
      expect(text, contains('Confidential: contains personal data'));
      expect(text, contains('Page 1 of 1'));
    });

    test('says so when nobody worked', () async {
      final report = ReportBuilder.team(
        _source(team),
        from: DateTime(2026, 10, 10),
        to: DateTime(2026, 10, 12),
      );

      final text = _text(
        await _renderer().render(report, generatedBy: 'Admin One'),
      );

      expect(text, contains('No duty was recorded in this period.'));
    });

    test('marks a blocked account and does not count its absences', () async {
      final blocked = _emp('b', 'Bala Singh', active: false);
      final report = ReportBuilder.team(
        _source([asha, blocked], [_s('1', 5, 'b', km: 1)]),
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 16),
      );

      final text = _text(
        await _renderer().render(report, generatedBy: 'Admin One'),
      );

      expect(text, contains('Bala Singh (blocked)'));
      expect(text, contains('Blocked accounts are listed only if they worked'));
    });

    test('keeps the table header on every page', () async {
      final many = [for (var i = 0; i < 160; i++) _emp('$i', 'Person $i')];
      final report = ReportBuilder.team(
        _source(many),
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 17),
      );

      final pdf = await _renderer().render(report, generatedBy: 'Admin One');
      final text = _text(pdf);
      final pages = _pages(pdf);

      expect(pages, greaterThan(2));
      expect('Days worked'.allMatches(text).length, pages);
      expect(text, contains('Page $pages of $pages'));
    });
  });

  group('employee summary', () {
    test(
      'lists each day, oldest first, with absent and flagged days',
      () async {
        final report = ReportBuilder.employee(
          _source(team, [
            _s('1', 12, 'a'),
            _s(
              '2',
              14,
              'a',
              minutes: 60,
              km: 1,
              status: 'auto_curfew',
              flagged: 2,
            ),
          ]),
          employee: asha,
          from: DateTime(2026, 10, 11),
          to: DateTime(2026, 10, 15),
        );

        final text = _text(
          await _renderer().render(report, generatedBy: 'Admin One'),
        );

        expect(text, contains('Employee Attendance Summary'));
        expect(text, contains('Asha Patel (DA-a)'));
        expect(text, contains('Sun, 11 Oct 2026'));
        expect(
          text.indexOf('Sun, 11 Oct 2026'),
          lessThan(text.indexOf('Thu, 15 Oct 2026')),
        );
        expect(text, contains('Absent'));
        expect(text, contains('Duty ended automatically'));
        expect(text, contains('2 flagged points'));
        expect(text, contains('Absent: a past day with no duty'));
      },
    );

    test(
      'a duty still running shows as in progress and is counted to now',
      () async {
        final report = ReportBuilder.employee(
          _source(team, [_s('1', 17, 'a', km: null, open: true)]),
          employee: asha,
          from: DateTime(2026, 10, 17),
          to: DateTime(2026, 10, 17),
        );

        final text = _text(
          await _renderer().render(report, generatedBy: 'Admin One'),
        );

        expect(text, contains('in progress'));
        expect(text, contains('1h 56m'));
        expect(
          text,
          contains('counted up to the time this report was generated'),
        );
        expect(text, contains('could not be measured'));
      },
    );

    test(
      'a period with no duty at all is still a valid PDF that says so',
      () async {
        final report = ReportBuilder.employee(
          _source([_emp('n', 'Newbie')]),
          employee: ReportEmployee(
            id: 'n',
            name: 'Newbie',
            code: 'DA-n',
            createdAt: DateTime.utc(2026, 10, 17),
          ),
          from: DateTime(2026, 10, 10),
          to: DateTime(2026, 10, 12),
        );

        final pdf = await _renderer().render(report, generatedBy: 'Admin One');

        expect(_pages(pdf), 1);
        expect(_text(pdf), contains('No duty recorded in this period'));
      },
    );
  });

  group('daily detail', () {
    test('lists the sessions and who was absent', () async {
      final report = ReportBuilder.daily(
        _source(team, [
          _s('1', 5, 'a'),
          _s(
            '2',
            5,
            'r',
            minutes: 120,
            km: 2,
            status: 'auto_curfew',
            flagged: 3,
          ),
        ]),
        day: DateTime(2026, 10, 5),
      );

      final text = _text(
        await _renderer().render(report, generatedBy: 'Admin One'),
      );

      expect(text, contains('Daily Duty Detail'));
      expect(text, contains('Mon, 05 Oct 2026'));
      expect(text, contains('8:04 AM'));
      expect(text, contains('4:04 PM'));
      expect(text, contains('Completed'));
      expect(text, contains('Duty ended automatically'));
      expect(text, contains('No duty recorded (1)'));
      expect(text, contains('Meena Rao (DA-m)'));
    });

    test('today lists no absences and says why', () async {
      final report = ReportBuilder.daily(
        _source(team, [_s('1', 17, 'a', km: null, open: true)]),
        day: DateTime(2026, 10, 17),
      );

      final text = _text(
        await _renderer().render(report, generatedBy: 'Admin One'),
      );

      expect(
        text,
        contains('Today is not over, so absences are not listed yet.'),
      );
      expect(text, contains('In progress'));
    });

    test('a day with no duty is a valid PDF that says so', () async {
      final report = ReportBuilder.daily(
        _source(team),
        day: DateTime(2026, 10, 5),
      );

      final text = _text(
        await _renderer().render(report, generatedBy: 'Admin One'),
      );

      expect(text, contains('No duty recorded on this day'));
      expect(text, contains('No duty recorded (3)'));
    });
  });

  group('every report', () {
    test('warns when the data was cut short', () async {
      final report = ReportBuilder.team(
        ReportSource(
          sessions: const [],
          employees: team,
          serverNow: _now,
          truncated: true,
        ),
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 17),
      );

      final text = _text(
        await _renderer().render(report, generatedBy: 'Admin One'),
      );

      expect(text, contains('This report is incomplete.'));
    });

    test('renders with the real DM Sans fonts and the logo', () async {
      final fonts = await ReportFonts.load();
      final logoData = await rootBundle.load('assets/image/white-logo.png');
      final logo = logoData.buffer.asUint8List();
      final report = ReportBuilder.team(
        _source(team, [_s('1', 5, 'a', km: 10.5)]),
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 17),
      );

      final pdf = await ReportPdfRenderer(
        fonts: fonts,
        logo: logo,
      ).render(report, generatedBy: 'Admin One');

      expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
      expect(pdf.length, greaterThan(20000));
    });
  });
}
