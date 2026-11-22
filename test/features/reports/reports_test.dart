import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/reports/application/reports_providers.dart';
import 'package:diamond_tracking/features/reports/data/report_pdf.dart';
import 'package:diamond_tracking/features/reports/domain/report.dart';
import 'package:diamond_tracking/features/reports/presentation/export_pdf_sheet.dart';
import 'package:diamond_tracking/features/reports/presentation/report_parts.dart';
import 'package:diamond_tracking/features/reports/presentation/reports_page.dart';
import 'package:diamond_tracking/features/requests/domain/app_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

DateTime d(int day, [int month = 11]) => DateTime.utc(2026, month, day);

ReportDay day(
  int id,
  String user,
  int date,
  DayStatus status, {
  LeaveType? leave,
  int? minutes,
  int? metres,
  int visits = 0,
}) => ReportDay(
  dayId: id,
  userId: user,
  day: d(date),
  status: status,
  leaveType: leave,
  dutyOnAt: minutes == null ? null : DateTime.utc(2026, 11, date, 1, 30),
  dutyOffAt: minutes == null
      ? null
      : DateTime.utc(2026, 11, date, 1, 30).add(Duration(minutes: minutes)),
  workedMinutes: minutes,
  distanceM: metres,
  visits: visits,
);

List<PersonReport> sample() => buildReports(
  people: const <({String id, String code, String name})>[
    (id: 'a', code: 'DA-001', name: 'Asha Roy'),
    (id: 'b', code: 'DA-002', name: 'Bikash Das'),
    (id: 'c', code: 'DA-003', name: 'No Days'),
  ],
  days: <ReportDay>[
    day(3, 'a', 3, DayStatus.absent),
    day(1, 'a', 1, DayStatus.present, minutes: 610, metres: 12400, visits: 3),
    day(2, 'a', 2, DayStatus.halfDay, minutes: 300, metres: 5100, visits: 1),
    day(4, 'a', 4, DayStatus.leave, leave: LeaveType.sick),
    day(5, 'b', 1, DayStatus.leave, leave: LeaveType.sick),
    day(6, 'b', 2, DayStatus.pending, minutes: 200, metres: 900),
  ],
);

void main() {
  group('totals', () {
    test('counts each status, duty time, km and visits', () {
      final List<PersonReport> r = sample();
      expect(r.map((PersonReport p) => p.name), <String>[
        'Asha Roy',
        'Bikash Das',
      ]);
      final PersonReport a = r.first;
      expect(a.days.map((ReportDay x) => x.day.day), <int>[1, 2, 3, 4]);
      expect((a.present, a.halfDays, a.absent, a.sickLeave), (1, 1, 1, 1));
      expect(formatDays(a.attendance), '1.5');
      expect(a.workedMinutes, 910);
      expect(a.distanceM, 17500);
      expect(a.visits, 4);
      expect(r[1].waiting, 1);
      expect(r[1].sickLeave, 1);
      expect(formatDays(r[1].attendance), '0');
    });

    test('a person carries their designation, or none', () {
      final List<PersonReport> r = buildReports(
        people: const <({String id, String code, String name})>[
          (id: 'a', code: 'DA-001', name: 'Asha Roy'),
          (id: 'b', code: 'DA-002', name: 'Bikash Das'),
        ],
        days: <ReportDay>[
          day(1, 'a', 1, DayStatus.present, minutes: 610),
          day(2, 'b', 1, DayStatus.absent),
        ],
        designations: const <String, String>{'a': 'Sales Officer'},
      );
      expect(r.map((PersonReport p) => p.designation), <String?>[
        'Sales Officer',
        null,
      ]);
    });

    test('filters days by status', () {
      final PersonReport a = sample().first;
      expect(a.filtered(StatusFilter.all), hasLength(4));
      expect(a.filtered(StatusFilter.absent).single.day, d(3));
      expect(a.filtered(StatusFilter.leave).single.statusLabel, 'Sick leave');
      expect(a.filtered(StatusFilter.waiting), isEmpty);
    });

    test('months cover the whole month, also across a year', () {
      final ReportRange nov = ReportRange.month(d(20));
      expect((nov.from, nov.to, nov.days), (d(1), d(30), 30));
      final ReportRange dec = ReportRange.month(DateTime.utc(2026, 12, 5));
      expect(dec.to, DateTime.utc(2026, 12, 31));
      final ReportRange feb = ReportRange.month(DateTime.utc(2028, 2, 10));
      expect(feb.days, 29);
      expect(nov.contains(d(30)), isTrue);
      expect(nov.contains(d(1, 12)), isFalse);
    });

    test('a database row reads leave type and visits', () {
      final ReportDay r = ReportDay.fromRow(<String, dynamic>{
        'id': 9,
        'user_id': 'a',
        'day': '2026-11-04',
        'status': 'leave',
        'leave_type': 'sick',
        'duty_on_at': null,
        'duty_off_at': null,
        'end_reason': null,
        'worked_minutes': null,
        'distance_m': null,
      }, visits: 2);
      expect((r.day, r.statusLabel, r.visits), (d(4), 'Sick leave', 2));
    });
  });

  group('pdf', () {
    test('summary and detail PDFs are made', () async {
      for (final bool detail in <bool>[false, true]) {
        final Uint8List bytes = await buildReportPdf(
          range: ReportRange.month(d(20)),
          people: sample(),
          filter: StatusFilter.all,
          detail: detail,
          madeAt: DateTime.utc(2026, 11, 20, 13),
        );
        expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
        expect(bytes.length, greaterThan(1000));
      }
    });

    test('an empty report still makes a PDF', () async {
      final Uint8List bytes = await buildReportPdf(
        range: ReportRange.month(d(20)),
        people: const <PersonReport>[],
        filter: StatusFilter.absent,
        detail: true,
        madeAt: DateTime.utc(2026, 11, 20, 13),
      );
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('names with accents print in DM Sans; others as "?" (L82)', () async {
      final ReportFonts fonts = ReportFonts(
        regular: ByteData.sublistView(
          File('assets/fonts/DMSans-Regular.ttf').readAsBytesSync(),
        ),
        bold: ByteData.sublistView(
          File('assets/fonts/DMSans-Bold.ttf').readAsBytesSync(),
        ),
      );
      final Set<int> dm = supportedRunes(fonts.regular);
      expect(fitText('José Núñez', dm), 'José Núñez');
      expect(fitText('রাহুল Das', dm), '????? Das');
      expect(fitText('José', supportedRunes(null)), 'Jos?');

      final List<PersonReport> people = buildReports(
        people: const <({String id, String code, String name})>[
          (id: 'a', code: 'DA-001', name: 'José Núñez'),
          (id: 'b', code: 'DA-002', name: 'রাহুল দাস'),
        ],
        designations: const <String, String>{'a': 'Field Assistant'},
        days: <ReportDay>[
          day(1, 'a', 1, DayStatus.present, minutes: 610),
          day(2, 'b', 1, DayStatus.absent),
        ],
      );
      for (final ReportFonts? f in <ReportFonts?>[fonts, null]) {
        final Uint8List bytes = await buildReportPdf(
          range: ReportRange.month(d(20)),
          people: people,
          filter: StatusFilter.all,
          detail: true,
          madeAt: DateTime.utc(2026, 11, 20, 13),
          fonts: f,
        );
        expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
      }
    });

    test('file name has the dates', () {
      expect(
        reportFileName(ReportRange.month(d(20))),
        'attendance-2026-11-01-to-2026-11-30.pdf',
      );
    });
  });

  group('page', () {
    late FakeReportsRepository repo;
    late FakePdfSharer sharer;
    setUp(() {
      repo = FakeReportsRepository(sample());
      sharer = FakePdfSharer();
    });

    List<Override> overrides() => <Override>[
      reportsRepositoryProvider.overrideWithValue(repo),
      pdfSharerProvider.overrideWithValue(sharer),
      // 20 Nov 2026, 6:30 PM IST.
      serverClockProvider.overrideWithValue(
        FixedClock(DateTime.utc(2026, 11, 20, 13)).clock,
      ),
    ];

    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
    }

    testWidgets('totals, waiting, by person; a person opens their history', (
      WidgetTester tester,
    ) async {
      tall(tester);
      await pumpPage(tester, const ReportsPage(), overrides: overrides());

      expect(repo.asked.single, ReportRange.month(d(20)));
      expect(find.bySemanticsLabel('Dates, 1 – 30 Nov 2026'), findsOneWidget);
      expect(find.bySemanticsLabel('Person, Everyone'), findsOneWidget);
      expect(find.bySemanticsLabel('Present 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Half day 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Leave 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Absent 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Duty time 18 h'), findsOneWidget);
      expect(find.bySemanticsLabel('Distance 18 km'), findsOneWidget);
      expect(find.bySemanticsLabel('Dealer visits 4'), findsOneWidget);
      expect(find.text('1 day still waiting'), findsOneWidget);
      expect(find.text('Asha Roy'), findsOneWidget);
      expect(find.text('1.5'), findsOneWidget);
      expect(find.text('15 h · 18 km · 4 visits'), findsOneWidget);
      expect(find.text('3 h · 1 km · 0 visits · 1 waiting'), findsOneWidget);

      await tester.tap(find.text('Asha Roy'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/users/a/days'), findsOneWidget);
    });

    testWidgets('sort by name, pick one person, Review opens requests', (
      WidgetTester tester,
    ) async {
      tall(tester);
      await pumpPage(tester, const ReportsPage(), overrides: overrides());
      // By attendance: Asha (1.5) before Bikash (0).
      expect(
        tester.getTopLeft(find.text('Asha Roy')).dy,
        lessThan(tester.getTopLeft(find.text('Bikash Das')).dy),
      );
      await tester.tap(find.bySemanticsLabel('Sort by Name'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Person, Everyone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bikash Das').last);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Person, Bikash Das'), findsOneWidget);
      expect(find.text('Asha Roy'), findsNothing);
      expect(find.bySemanticsLabel('Leave 1'), findsOneWidget);

      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/requests'), findsOneWidget);
    });

    testWidgets('last month asks for October', (WidgetTester tester) async {
      tall(tester);
      await pumpPage(tester, const ReportsPage(), overrides: overrides());
      await tester.tap(find.bySemanticsLabel('Last month'));
      await tester.pumpAndSettle();
      expect(repo.asked.last, ReportRange.month(d(1, 10)));
      expect(find.bySemanticsLabel('Dates, 1 – 31 Oct 2026'), findsOneWidget);
    });

    testWidgets('the PDF goes to the share sheet', (WidgetTester tester) async {
      tall(tester);
      await pumpPage(tester, const ReportsPage(), overrides: overrides());
      await tester.tap(find.text('Download PDF'));
      await tester.pumpAndSettle();
      expect(find.text('Download report'), findsOneWidget);
      expect(find.bySemanticsLabel('1 – 30 Nov 2026'), findsOneWidget);
      expect(find.text('Create PDF · about 1 page'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('^Every day')));
      await tester.pumpAndSettle();
      expect(find.text('Create PDF · about 3 pages'), findsOneWidget);
      await tester.tap(find.text('Create PDF · about 3 pages'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pumpAndSettle();
      expect(
        sharer.shared.single.$2,
        'attendance-2026-11-01-to-2026-11-30.pdf',
      );
      expect(sharer.shared.single.$1, greaterThan(1000));
      // Written into the admin log (L84).
      expect(repo.exports.single, (ReportRange.month(d(20)), true, 2));
      expect(find.text('Download report'), findsNothing);
    });

    testWidgets('which days can be picked for the PDF', (
      WidgetTester tester,
    ) async {
      tall(tester);
      await pumpPage(tester, const ReportsPage(), overrides: overrides());
      await tester.tap(find.bySemanticsLabel('Download PDF').first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('All days'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Absent'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('All days'), findsNothing);
      expect(find.text('Download report'), findsOneWidget);
    });

    testWidgets('a failed log entry does not stop the PDF (L84)', (
      WidgetTester tester,
    ) async {
      tall(tester);
      repo.failLog = true;
      await pumpPage(tester, const ReportsPage(), overrides: overrides());
      await tester.tap(find.text('Download PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create PDF · about 1 page'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pumpAndSettle();
      expect(sharer.shared, hasLength(1));
      expect(find.textContaining('could not'), findsNothing);
    });

    testWidgets('no records says so', (WidgetTester tester) async {
      repo.people = <PersonReport>[];
      await pumpPage(tester, const ReportsPage(), overrides: overrides());
      expect(find.text('No records in these dates'), findsOneWidget);
    });

    for (final double width in <double>[360, 390, 430]) {
      testWidgets('reports fit ${width.toInt()} wide', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await pumpPage(tester, const ReportsPage(), overrides: overrides());
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Download PDF'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    test('page estimate', () {
      expect(reportPages(sample(), detail: false), 1);
      expect(reportPages(sample(), detail: true), 3);
    });

    test('range labels', () {
      expect(rangeLabel(ReportRange(d(1), d(21))), '1 – 21 Nov');
      expect(rangeLabel(ReportRange(d(28, 10), d(3))), '28 Oct – 3 Nov');
      expect(
        rangeLabel(ReportRange(d(1), d(21)), withYear: true),
        '1 – 21 Nov 2026',
      );
    });
  });
}
