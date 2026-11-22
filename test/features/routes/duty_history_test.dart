import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/reports/application/reports_providers.dart';
import 'package:diamond_tracking/features/reports/domain/report.dart';
import 'package:diamond_tracking/features/requests/application/requests_providers.dart';
import 'package:diamond_tracking/features/requests/domain/app_request.dart';
import 'package:diamond_tracking/features/routes/application/route_providers.dart';
import 'package:diamond_tracking/features/routes/presentation/duty_history_page.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:flutter/material.dart' show BottomSheet, Size;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  // 13:30 IST on Friday 20 Nov 2026.
  final DateTime now = DateTime.utc(2026, 11, 20, 8);
  late FakeRouteRepository routes;
  late FakeReportsRepository reports;
  late FakeRequestsRepository requests;
  setUp(() {
    routes = FakeRouteRepository();
    reports = FakeReportsRepository();
    requests = FakeRequestsRepository();
  });

  List<Override> overrides() => <Override>[
    routeRepositoryProvider.overrideWithValue(routes),
    reportsRepositoryProvider.overrideWithValue(reports),
    requestsRepositoryProvider.overrideWithValue(requests),
    serverClockProvider.overrideWithValue(FixedClock(now).clock),
  ];

  final FakeUsersRepository people = FakeUsersRepository(<Profile>[
    profile('u', code: 'EMP003', name: 'Amit Roy'),
  ]);

  DutyDay day(
    int id,
    int date,
    DayStatus status, {
    bool duty = false,
    LeaveType? leave,
  }) => DutyDay(
    id: id,
    userId: 'u',
    day: DateTime.utc(2026, 11, date),
    status: status,
    leaveType: leave,
    dutyOnAt: duty ? DateTime.utc(2026, 11, date, 1, 30) : null,
    dutyOffAt: duty && status != DayStatus.onDuty
        ? DateTime.utc(2026, 11, date, 12)
        : null,
    workedMinutes: duty && status != DayStatus.onDuty ? 630 : null,
    distanceM: duty ? 30000 : null,
  );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'month totals, calendar, today picked; a worked day has a route',
    (WidgetTester tester) async {
      tall(tester);
      routes.days[1] = day(1, 18, DayStatus.present, duty: true);
      routes.days[2] = day(2, 19, DayStatus.halfDay, duty: true);
      routes.days[3] = day(3, 17, DayStatus.leave, leave: LeaveType.casual);
      routes.days[4] = day(4, 16, DayStatus.absent);
      routes.days[5] = day(5, 20, DayStatus.onDuty, duty: true);
      await pumpPage(
        tester,
        const DutyHistoryPage(userId: 'u'),
        users: people,
        overrides: overrides(),
      );
      expect(find.text('Amit Roy'), findsOneWidget);
      expect(find.text('AR'), findsOneWidget);
      expect(find.bySemanticsLabel('Present 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Half day 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Leave 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Absent 1'), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('27 h · 90.0 km'), findsOneWidget);
      // Today is picked: on duty now.
      expect(find.text('On duty now'), findsOneWidget);
      expect(find.text('7:00 AM → now'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('18 November, Present'));
      await tester.pumpAndSettle();
      expect(find.text('7:00 AM → 5:30 PM'), findsOneWidget);
      expect(find.bySemanticsLabel('Worked 10h 30m'), findsOneWidget);
      expect(find.bySemanticsLabel('Distance 30.0 km'), findsOneWidget);
      await tester.tap(find.text('View route of this day'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/days/1'), findsOneWidget);
    },
  );

  testWidgets('an absent day can be changed; a leave day says so', (
    WidgetTester tester,
  ) async {
    tall(tester);
    routes.days[3] = day(3, 17, DayStatus.leave, leave: LeaveType.casual);
    routes.days[4] = day(4, 16, DayStatus.absent);
    await pumpPage(
      tester,
      const DutyHistoryPage(userId: 'u'),
      users: people,
      overrides: overrides(),
    );
    await tester.tap(find.bySemanticsLabel('17 November, Casual leave'));
    await tester.pumpAndSettle();
    expect(
      find.text('Casual leave, approved. Not counted as absent.'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('16 November, Absent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change day status'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Present'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(requests.calls.single, 'setDayStatus:u:2026-11-16:present::');
  });

  testWidgets('months go back 90 days, not forward past today', (
    WidgetTester tester,
  ) async {
    tall(tester);
    await pumpPage(
      tester,
      const DutyHistoryPage(userId: 'u'),
      users: people,
      overrides: overrides(),
    );
    expect(find.text('Nothing recorded'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    for (final String m in <String>[
      'October 2026',
      'September 2026',
      'August 2026',
    ]) {
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text(m), findsOneWidget);
    }
    await tester.tap(find.bySemanticsLabel('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);
  });

  testWidgets("download opens this person's report sheet", (
    WidgetTester tester,
  ) async {
    tall(tester);
    reports.people = buildReports(
      people: const <({String id, String code, String name})>[
        (id: 'u', code: 'EMP003', name: 'Amit Roy'),
      ],
      days: <ReportDay>[
        ReportDay(
          dayId: 1,
          userId: 'u',
          day: DateTime.utc(2026, 11, 18),
          status: DayStatus.present,
        ),
      ],
    );
    await pumpPage(
      tester,
      const DutyHistoryPage(userId: 'u'),
      users: people,
      overrides: overrides(),
    );
    await tester.tap(find.bySemanticsLabel("Download this person's report"));
    await tester.pumpAndSettle();
    expect(find.text('Download report'), findsOneWidget);
    expect(find.bySemanticsLabel('1 – 20 Nov 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('Amit Roy'), findsOneWidget);
  });

  for (final double width in <double>[360, 390, 430]) {
    testWidgets('fits ${width.toInt()} wide', (WidgetTester tester) async {
      tester.view.physicalSize = Size(width * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      routes.days[5] = day(5, 20, DayStatus.onDuty, duty: true);
      await pumpPage(
        tester,
        const DutyHistoryPage(userId: 'u'),
        users: FakeUsersRepository(<Profile>[
          profile('u', name: 'Mohammad Hasanur Rahaman Chowdhury'),
        ]),
        overrides: overrides(),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
