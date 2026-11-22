import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/duty/application/duty_providers.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/routes/application/route_providers.dart';
import 'package:diamond_tracking/features/routes/domain/day_route.dart';
import 'package:diamond_tracking/features/routes/domain/geo_point.dart';
import 'package:diamond_tracking/features/routes/domain/live_position.dart';
import 'package:diamond_tracking/features/routes/presentation/day_route_page.dart';
import 'package:diamond_tracking/features/routes/presentation/history_page.dart';
import 'package:diamond_tracking/features/routes/presentation/live_map_page.dart';
import 'package:diamond_tracking/features/routes/presentation/my_map_page.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:diamond_tracking/features/visits/domain/visit.dart';
import 'package:diamond_tracking/shared/ds/ds_chips.dart';
import 'package:flutter/material.dart' show Size;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  // 2026-11-20 13:30 IST.
  final DateTime now = DateTime.utc(2026, 11, 20, 8);
  DateTime at(int min) =>
      DateTime.utc(2026, 11, 20, 3).add(Duration(minutes: min));
  final DateTime today = DateTime.utc(2026, 11, 20);

  const SignedIn employee = SignedIn(
    userId: 'u',
    role: AppRole.employee,
    mustChangePassword: false,
  );

  late FakeRouteRepository routes;
  setUp(() => routes = FakeRouteRepository());

  List<Override> overrides({FakeDutyRepository? duty}) => <Override>[
    routeRepositoryProvider.overrideWithValue(routes),
    showGoogleMapProvider.overrideWithValue(false),
    serverClockProvider.overrideWithValue(FixedClock(now).clock),
    if (duty != null) dutyRepositoryProvider.overrideWithValue(duty),
  ];

  DutyDay day(
    int id, {
    String user = 'u',
    DateTime? on,
    DayStatus status = DayStatus.present,
    DateTime? date,
    int? distance,
  }) => DutyDay(
    id: id,
    userId: user,
    day: date ?? today,
    status: status,
    dutyOnAt: on,
    dutyOffAt: status == DayStatus.onDuty || on == null ? null : at(480),
    workedMinutes: on == null ? null : 480,
    distanceM: distance,
  );

  DayRoute route(
    int id, {
    List<String?> addresses = const <String?>[null],
    int mocked = 0,
  }) => DayRoute(
    dayId: id,
    segments: const <List<GeoPoint>>[
      <GeoPoint>[GeoPoint(22.5, 88.3), GeoPoint(22.6, 88.4)],
    ],
    stops: <RouteStop>[
      for (int i = 0; i < addresses.length; i++)
        RouteStop(
          point: const GeoPoint(22.55, 88.35),
          start: at(60 + i * 120),
          end: at(100 + i * 120),
          address: addresses[i],
        ),
    ],
    notes: <RouteNote>[
      RouteNote(from: at(200), to: at(230), kind: NoteKind.phoneOff),
    ],
    distanceM: 12400,
    pointCount: 80,
    mockedPoints: mocked,
  );

  testWidgets('a day\'s route lists stops and notes, then fills addresses', (
    WidgetTester tester,
  ) async {
    routes.days[7] = day(7, on: at(0));
    routes.routes[7] = route(7);
    routes.addressesToFind = <int, String>{0: 'City Centre, Salt Lake'};

    await pumpPage(
      tester,
      const DayRoutePage(dayId: 7, personName: 'Asha Roy'),
      overrides: overrides(),
    );

    expect(find.textContaining('Asha Roy ·'), findsOneWidget);
    expect(find.text('Map: 1 lines, 0 gaps, 3 pins'), findsOneWidget);
    expect(find.text('12.4 km'), findsOneWidget);
    expect(find.text('Present'), findsOneWidget);
    expect(find.textContaining('Phone was off'), findsOneWidget);
    // The address was asked for once and the route reloaded with it.
    expect(routes.addressRequests, 1);
    expect(find.text('City Centre, Salt Lake'), findsOneWidget);
    expect(find.text('Finding address…'), findsNothing);
  });

  testWidgets('a route with no addresses yet says so, and asks only once', (
    WidgetTester tester,
  ) async {
    routes.days[8] = day(8, on: at(0));
    routes.routes[8] = route(8);

    await pumpPage(
      tester,
      const DayRoutePage(dayId: 8, personName: 'Asha Roy'),
      overrides: overrides(),
    );
    expect(find.text('Finding address…'), findsOneWidget);
    expect(routes.addressRequests, 1);
  });

  group('My map', () {
    final Visit visit = Visit(
      id: 'v1',
      storeName: 'Maa Tara Traders',
      fromGallery: false,
      capturedAt: at(90),
      location: const GeoPoint(22.56, 88.36),
    );

    testWidgets('before duty on: no route, nothing to open', (
      WidgetTester tester,
    ) async {
      await pumpPage(
        tester,
        const MyMapPage(),
        status: employee,
        overrides: overrides(duty: FakeDutyRepository()),
      );
      expect(find.text('Not started'), findsOneWidget);
      expect(find.textContaining('No route today'), findsOneWidget);
      expect(find.bySemanticsLabel('Add visit, duty on first'), findsOneWidget);
      await tester.tap(find.text('Stops & timeline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('route /'), findsNothing);
    });

    testWidgets('on duty: figures, pins, timeline and Add visit', (
      WidgetTester tester,
    ) async {
      final DutyDay d = day(9, on: at(0), status: DayStatus.onDuty);
      routes.days[9] = d;
      routes.routes[9] = route(9, addresses: <String?>['Office, Sector V']);
      final FakeVisitsRepository visits = FakeVisitsRepository()
        ..byDay[9] = <Visit>[visit];

      await pumpPage(
        tester,
        const MyMapPage(),
        status: employee,
        visits: visits,
        overrides: overrides(duty: FakeDutyRepository(today: d)),
      );
      expect(find.text('Recording'), findsOneWidget);
      expect(find.text('Today, 20 Nov'), findsOneWidget);
      // Start, stop 1, the visit, and "You".
      expect(find.text('Map: 1 lines, 0 gaps, 4 pins'), findsOneWidget);
      expect(find.bySemanticsLabel('Distance 12.4 km'), findsOneWidget);
      // 8:30 AM to 1:30 PM.
      expect(find.bySemanticsLabel('On duty 5h 00m'), findsOneWidget);
      expect(find.bySemanticsLabel('Visits 1'), findsOneWidget);
      expect(find.text('Updated just now'), findsOneWidget);
      expect(routes.addressRequests, 0);

      await tester.tap(find.bySemanticsLabel('Add visit'));
      await tester.pumpAndSettle();
      expect(find.text('route /home/visit/9'), findsOneWidget);
    });

    testWidgets('Stops & timeline opens the day', (WidgetTester tester) async {
      final DutyDay d = day(9, on: at(0), status: DayStatus.onDuty);
      routes.days[9] = d;
      routes.routes[9] = route(9);
      await pumpPage(
        tester,
        const MyMapPage(),
        status: employee,
        overrides: overrides(duty: FakeDutyRepository(today: d)),
      );
      await tester.tap(find.text('Stops & timeline'));
      await tester.pumpAndSettle();
      expect(find.text('route /history/day/9'), findsOneWidget);
    });

    testWidgets('after duty off: worked time, no Add visit', (
      WidgetTester tester,
    ) async {
      final DutyDay d = day(9, on: at(0));
      routes.days[9] = d;
      routes.routes[9] = const DayRoute(
        dayId: 9,
        segments: <List<GeoPoint>>[
          <GeoPoint>[GeoPoint(22.5, 88.3), GeoPoint(22.6, 88.4)],
          <GeoPoint>[GeoPoint(22.7, 88.5), GeoPoint(22.8, 88.6)],
        ],
        stops: <RouteStop>[],
        notes: <RouteNote>[],
        distanceM: 30000,
        pointCount: 40,
        mockedPoints: 0,
      );
      await pumpPage(
        tester,
        const MyMapPage(),
        status: employee,
        overrides: overrides(duty: FakeDutyRepository(today: d)),
      );
      expect(find.text('Duty off'), findsOneWidget);
      // The two stretches are joined by one dotted gap; start and end pins.
      expect(find.text('Map: 2 lines, 1 gaps, 2 pins'), findsOneWidget);
      expect(find.bySemanticsLabel('On duty 8h 00m'), findsOneWidget);
      expect(find.bySemanticsLabel('Add visit, duty on first'), findsOneWidget);
    });

    testWidgets('a failed load offers Retry', (WidgetTester tester) async {
      final FakeDutyRepository duty = FakeDutyRepository()
        ..forDayError = Exception('offline');
      await pumpPage(
        tester,
        const MyMapPage(),
        status: employee,
        overrides: overrides(duty: duty),
      );
      expect(find.text("Couldn't load your route"), findsOneWidget);
      duty.forDayError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Not started'), findsOneWidget);
    });

    for (final Size phone in const <Size>[
      Size(360, 740),
      Size(390, 844),
      Size(430, 932),
    ]) {
      testWidgets('fits ${phone.width.toInt()} wide', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = phone;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final DutyDay d = day(9, on: at(0), status: DayStatus.onDuty);
        routes.days[9] = d;
        routes.routes[9] = route(9, mocked: 3);
        await pumpPage(
          tester,
          const MyMapPage(),
          status: employee,
          overrides: overrides(duty: FakeDutyRepository(today: d)),
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Fake GPS'), findsOneWidget);
      });
    }
  });

  testWidgets('History lists days newest first and opens a day', (
    WidgetTester tester,
  ) async {
    routes.days[1] = day(
      1,
      on: at(0),
      date: DateTime.utc(2026, 11, 18),
      distance: 5000,
    );
    routes.days[2] = day(
      2,
      date: DateTime.utc(2026, 11, 19),
      status: DayStatus.absent,
    );
    routes.days[3] = day(3, user: 'other', on: at(0));

    await pumpPage(
      tester,
      HistoryPage(dayRoute: (int id) => '/history/day/$id'),
      status: employee,
      overrides: overrides(),
    );
    final Finder absentCard = find.widgetWithText(DsStatusPill, 'Absent');
    expect(absentCard, findsOneWidget);
    expect(find.textContaining('5.0 km'), findsOneWidget);
    expect(find.byType(HistoryPage), findsOneWidget);

    // The absent day has no route to open.
    await tester.tap(absentCard);
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPage), findsOneWidget);

    await tester.tap(find.textContaining('5.0 km'));
    await tester.pumpAndSettle();
    expect(find.text('route /history/day/1'), findsOneWidget);
  });

  testWidgets('a route with fake GPS points warns', (
    WidgetTester tester,
  ) async {
    routes.days[8] = day(8, on: at(0));
    routes.routes[8] = route(8, addresses: const <String?>['Shop'], mocked: 12);
    await pumpPage(
      tester,
      const DayRoutePage(dayId: 8, personName: 'Asha Roy'),
      overrides: overrides(),
    );
    expect(find.textContaining('Fake GPS: 12 points'), findsOneWidget);
  });

  testWidgets('a route without fake GPS shows no warning', (
    WidgetTester tester,
  ) async {
    routes.days[8] = day(8, on: at(0));
    routes.routes[8] = route(8, addresses: const <String?>['Shop']);
    await pumpPage(
      tester,
      const DayRoutePage(dayId: 8, personName: 'Asha Roy'),
      overrides: overrides(),
    );
    expect(find.textContaining('Fake GPS'), findsNothing);
  });

  testWidgets('the live map marks a fake position', (
    WidgetTester tester,
  ) async {
    routes.days[20] = day(20, user: 'u', on: at(0), status: DayStatus.onDuty);
    routes.initialLive = <LivePosition>[
      LivePosition(
        userId: 'u',
        dutyDayId: 20,
        point: const GeoPoint(22.5, 88.3),
        recordedAt: now.subtract(const Duration(minutes: 1)),
        mocked: true,
      ),
    ];
    await pumpPage(
      tester,
      const LiveMapPage(),
      users: FakeUsersRepository(<Profile>[profile('u', name: 'Asha Roy')]),
      overrides: overrides(),
    );
    expect(find.textContaining('Fake GPS'), findsOneWidget);
  });

  testWidgets('the live map lists people and opens a route', (
    WidgetTester tester,
  ) async {
    routes.days[20] = day(20, user: 'u', on: at(0), status: DayStatus.onDuty);
    routes.days[21] = day(21, user: 'v', on: at(0));
    routes.initialLive = <LivePosition>[
      LivePosition(
        userId: 'u',
        dutyDayId: 20,
        point: const GeoPoint(22.5, 88.3),
        recordedAt: now.subtract(const Duration(minutes: 1)),
        battery: 64,
      ),
    ];

    await pumpPage(
      tester,
      const LiveMapPage(),
      users: FakeUsersRepository(<Profile>[
        profile('u', name: 'Asha Roy'),
        profile('v', name: 'Bikash Das'),
      ]),
      overrides: overrides(),
    );
    expect(find.text('Map: 0 lines, 0 gaps, 1 pins'), findsOneWidget);
    expect(find.textContaining('Battery 64%'), findsOneWidget);
    expect(find.text('Bikash Das'), findsOneWidget);

    // A position older than 5 minutes shows as stale.
    routes.live.add(<LivePosition>[
      LivePosition(
        userId: 'u',
        dutyDayId: 20,
        point: const GeoPoint(22.5, 88.3),
        recordedAt: now.subtract(const Duration(minutes: 20)),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.textContaining('No update since'), findsOneWidget);

    await tester.tap(find.text('Asha Roy'));
    await tester.pumpAndSettle();
    expect(find.text('route /admin/days/20'), findsOneWidget);
  });

  testWidgets('the live map says when nobody is on duty', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, const LiveMapPage(), overrides: overrides());
    expect(find.text('Nobody on duty yet'), findsOneWidget);
  });
}
