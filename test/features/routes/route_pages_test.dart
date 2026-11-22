import 'package:diamond_tracking/core/design/ds_icons.dart';
import 'package:diamond_tracking/core/links/open_link.dart';
import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/duty/application/duty_providers.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/requests/application/requests_providers.dart';
import 'package:diamond_tracking/features/requests/domain/app_request.dart';
import 'package:diamond_tracking/features/routes/application/route_providers.dart';
import 'package:diamond_tracking/features/routes/domain/day_route.dart';
import 'package:diamond_tracking/features/routes/domain/geo_point.dart';
import 'package:diamond_tracking/features/routes/domain/live_position.dart';
import 'package:diamond_tracking/features/routes/presentation/day_route_page.dart';
import 'package:diamond_tracking/features/routes/presentation/history_page.dart';
import 'package:diamond_tracking/features/routes/presentation/live_map_page.dart';
import 'package:diamond_tracking/features/routes/presentation/live_person_page.dart';
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

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

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

  group('Day route', () {
    final FakeUsersRepository people = FakeUsersRepository(<Profile>[
      profile('u', code: 'EMP007', name: 'Asha Roy'),
    ]);

    testWidgets('admin: who, figures, hours strip, timeline, addresses', (
      WidgetTester tester,
    ) async {
      tall(tester);
      routes.days[7] = day(7, on: at(0));
      routes.routes[7] = route(7);
      routes.addressesToFind = <int, String>{0: 'City Centre, Salt Lake'};

      await pumpPage(
        tester,
        const DayRoutePage(dayId: 7),
        users: people,
        overrides: overrides(),
      );

      expect(find.text('Asha Roy'), findsOneWidget);
      expect(find.text('EMP007'), findsOneWidget);
      expect(find.text('AR'), findsOneWidget);
      expect(find.text('Today · Fri, 20 Nov'), findsOneWidget);
      expect(find.text('Map: 1 lines, 0 gaps, 3 pins'), findsOneWidget);
      expect(find.text('12.4 km'), findsOneWidget);
      expect(find.text('8h 00m'), findsOneWidget);
      expect(find.text('1 · 0'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      // The hours strip (admin only).
      expect(find.text('Recorded'), findsOneWidget);
      expect(find.text('5 AM'), findsOneWidget);
      // Timeline: duty on, the stop, the phone-off gap, duty off.
      expect(find.text('Duty on'), findsOneWidget);
      expect(find.text('Duty off'), findsOneWidget);
      expect(find.textContaining('Phone was off · 30 min'), findsOneWidget);
      // The address was asked for once and the route reloaded with it.
      expect(routes.addressRequests, 1);
      expect(find.text('City Centre, Salt Lake'), findsOneWidget);
      expect(find.text('Finding address…'), findsNothing);
    });

    testWidgets('a route with no addresses yet says so, and asks only once', (
      WidgetTester tester,
    ) async {
      tall(tester);
      routes.days[8] = day(8, on: at(0));
      routes.routes[8] = route(8);

      await pumpPage(
        tester,
        const DayRoutePage(dayId: 8),
        overrides: overrides(),
      );
      expect(find.text('Finding address…'), findsOneWidget);
      expect(routes.addressRequests, 1);
    });

    testWidgets('employee: date, duty bar, no hours strip', (
      WidgetTester tester,
    ) async {
      tall(tester);
      routes.days[7] = day(7, on: at(0));
      routes.routes[7] = route(7, addresses: const <String?>['Shop']);

      await pumpPage(
        tester,
        const DayRoutePage(dayId: 7),
        users: people,
        status: employee,
        overrides: overrides(),
      );

      expect(find.text('Friday'), findsOneWidget);
      expect(find.text('20 November'), findsOneWidget);
      expect(find.text('Asha Roy'), findsNothing);
      expect(find.text('Recorded'), findsNothing);
      // 8 hours of the 10 hour goal.
      expect(find.text('8h 00m of 10 h'), findsOneWidget);
      expect(find.text('8:30 AM on'), findsOneWidget);
      expect(find.text('4:30 PM off'), findsOneWidget);
    });

    testWidgets('a full day says the goal is met', (WidgetTester tester) async {
      tall(tester);
      routes.days[7] = DutyDay(
        id: 7,
        userId: 'u',
        day: today,
        status: DayStatus.present,
        dutyOnAt: at(0),
        dutyOffAt: at(630),
        workedMinutes: 630,
      );
      await pumpPage(
        tester,
        const DayRoutePage(dayId: 7),
        status: employee,
        overrides: overrides(),
      );
      expect(find.text('10 h goal met'), findsOneWidget);
    });

    testWidgets('visits sit under their stop, and the Visits tab opens one', (
      WidgetTester tester,
    ) async {
      tall(tester);
      final FakeVisitsRepository visits = FakeVisitsRepository();
      routes.days[7] = day(7, on: at(0));
      routes.routes[7] = route(7, addresses: const <String?>['Shop Rd']);
      visits.byDay[7] = <Visit>[
        Visit(
          id: 'v1',
          storeName: 'Maa Tara Agro',
          fromGallery: false,
          capturedAt: at(70),
          location: const GeoPoint(22.55, 88.35),
        ),
        Visit(
          id: 'v2',
          storeName: 'Roadside Seeds',
          fromGallery: true,
          capturedAt: at(300),
        ),
      ];

      await pumpPage(
        tester,
        const DayRoutePage(dayId: 7),
        visits: visits,
        status: employee,
        overrides: overrides(),
      );

      expect(find.text('1 visit'), findsOneWidget);
      expect(find.text('Maa Tara Agro'), findsOneWidget);
      expect(find.text('Roadside Seeds'), findsOneWidget);

      await tester.tap(find.text('Visits · 2'));
      await tester.pumpAndSettle();
      expect(find.text('Stop 1'), findsOneWidget);
      expect(find.text('Away from a stop'), findsOneWidget);
      await tester.tap(find.text('Maa Tara Agro'));
      await tester.pumpAndSettle();
      expect(find.text('Place saved'), findsOneWidget);
      expect(find.text('22.55000, 88.35000'), findsOneWidget);
    });

    testWidgets('on duty: "Now" and a reload every 2 minutes', (
      WidgetTester tester,
    ) async {
      tall(tester);
      routes.days[9] = day(9, on: at(0), status: DayStatus.onDuty);
      routes.routes[9] = route(9, addresses: const <String?>['Shop']);

      await pumpPage(
        tester,
        const DayRoutePage(dayId: 9),
        overrides: overrides(),
      );
      expect(find.text('Now · on duty'), findsOneWidget);
      expect(find.text('Updated just now'), findsOneWidget);
      expect(find.text('On duty now'), findsOneWidget);
      // On duty for 5 h (8:30 AM to 1:30 PM).
      expect(find.text('5h 00m'), findsOneWidget);
      expect(find.text('Duty off'), findsNothing);

      routes.routes[9] = route(9, addresses: const <String?>['New Market']);
      await tester.pump(DayRoutePage.refreshEvery);
      await tester.pumpAndSettle();
      expect(find.text('New Market'), findsOneWidget);
    });

    testWidgets('full screen map hides the details and brings them back', (
      WidgetTester tester,
    ) async {
      routes.days[7] = day(7, on: at(0));
      routes.routes[7] = route(7, addresses: const <String?>['Shop']);
      await pumpPage(
        tester,
        const DayRoutePage(dayId: 7),
        overrides: overrides(),
      );

      await tester.tap(find.bySemanticsLabel('Full screen map'));
      await tester.pumpAndSettle();
      expect(find.text('Duty on'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Show the details'));
      await tester.pumpAndSettle();
      expect(find.text('Duty on'), findsOneWidget);
    });

    testWidgets('a leave day has no route to show', (
      WidgetTester tester,
    ) async {
      routes.days[7] = DutyDay(
        id: 7,
        userId: 'u',
        day: today,
        status: DayStatus.leave,
      );
      await pumpPage(
        tester,
        const DayRoutePage(dayId: 7),
        status: employee,
        overrides: overrides(),
      );
      expect(find.text('No duty this day'), findsOneWidget);
      expect(find.text('On leave'), findsOneWidget);
    });

    testWidgets('a failed load can be tried again', (
      WidgetTester tester,
    ) async {
      routes.dayError = Exception('offline');
      await pumpPage(
        tester,
        const DayRoutePage(dayId: 7),
        overrides: overrides(),
      );
      expect(find.text("Couldn't load this day"), findsOneWidget);
      routes
        ..dayError = null
        ..days[7] = day(7, on: at(0))
        ..routes[7] = route(7, addresses: const <String?>['Shop']);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Shop'), findsOneWidget);
    });

    for (final bool admin in <bool>[true, false]) {
      for (final double width in <double>[360, 390, 430]) {
        testWidgets('${admin ? 'admin' : 'employee'} day fits $width wide', (
          WidgetTester tester,
        ) async {
          tester.view.physicalSize = Size(width * 3, 800 * 3);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          routes.days[7] = day(7, on: at(0), status: DayStatus.onDuty);
          routes.routes[7] = route(
            7,
            addresses: const <String?>[
              'Krishi Kendra Road near the old bus stand, Barasat',
              null,
            ],
            mocked: 3,
          );
          await pumpPage(
            tester,
            const DayRoutePage(dayId: 7),
            users: FakeUsersRepository(<Profile>[
              profile('u', name: 'Mohammad Hasanur Rahaman Chowdhury'),
            ]),
            status: admin
                ? const SignedIn(
                    userId: 'a',
                    role: AppRole.admin,
                    mustChangePassword: false,
                  )
                : employee,
            overrides: overrides(),
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Visits · 0'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
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

  testWidgets('a leave day in History opens its leave request', (
    WidgetTester tester,
  ) async {
    routes.days[4] = day(
      4,
      date: DateTime.utc(2026, 11, 17),
      status: DayStatus.leave,
    );
    final FakeRequestsRepository requests = FakeRequestsRepository()
      ..requests.add(
        AppRequest(
          id: 77,
          userId: 'u',
          kind: RequestKind.leave,
          status: RequestStatus.approved,
          createdAt: DateTime.utc(2026, 11, 10),
          leaveType: LeaveType.casual,
          dates: <DateTime>[DateTime.utc(2026, 11, 17)],
        ),
      );
    await pumpPage(
      tester,
      HistoryPage(
        dayRoute: (int id) => '/history/day/$id',
        requestRoute: (int id) => '/home/requests/$id',
      ),
      status: employee,
      overrides: <Override>[
        ...overrides(),
        requestsRepositoryProvider.overrideWithValue(requests),
      ],
    );
    await tester.tap(find.widgetWithText(DsStatusPill, 'On leave'));
    await tester.pumpAndSettle();
    expect(find.text('route /home/requests/77'), findsOneWidget);
  });

  testWidgets('a route with fake GPS points warns', (
    WidgetTester tester,
  ) async {
    routes.days[8] = day(8, on: at(0));
    routes.routes[8] = route(8, addresses: const <String?>['Shop'], mocked: 12);
    await pumpPage(
      tester,
      const DayRoutePage(dayId: 8),
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
      const DayRoutePage(dayId: 8),
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
    expect(find.text('route /admin/live/20'), findsOneWidget);
  });

  testWidgets('the live map says when nobody is on duty', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, const LiveMapPage(), overrides: overrides());
    expect(find.text('Nobody on duty yet'), findsOneWidget);
  });
  group('Live map, one person', () {
    final FakeUsersRepository people = FakeUsersRepository(<Profile>[
      const Profile(
        id: 'u',
        userCode: 'EMP007',
        fullName: 'Rahul Das',
        role: AppRole.employee,
        isActive: true,
        phone: '9876543210',
      ),
    ]);

    LivePosition position(
      int minutesAgo, {
      int? battery,
      bool mocked = false,
    }) => LivePosition(
      userId: 'u',
      dutyDayId: 30,
      point: const GeoPoint(22.7, 88.5),
      recordedAt: now.subtract(Duration(minutes: minutesAgo)),
      battery: battery,
      mocked: mocked,
    );

    testWidgets('live: name, status, battery, figures, pins and actions', (
      WidgetTester tester,
    ) async {
      routes.days[30] = day(30, on: at(0), status: DayStatus.onDuty);
      routes.routes[30] = route(30, addresses: const <String?>['Station Rd']);
      routes.initialLive = <LivePosition>[position(1, battery: 64)];
      final List<Uri> opened = <Uri>[];
      await pumpPage(
        tester,
        const LivePersonPage(dayId: 30),
        users: people,
        overrides: <Override>[
          ...overrides(),
          openLinkProvider.overrideWithValue((Uri uri) async {
            opened.add(uri);
            return true;
          }),
        ],
      );
      expect(find.text('Rahul Das'), findsOneWidget);
      expect(find.text('RD'), findsOneWidget);
      expect(find.textContaining('Live'), findsWidgets);
      expect(find.textContaining('1 min ago · since 8:30 AM'), findsOneWidget);
      expect(find.text('64%'), findsOneWidget);
      // Start, one stop and where he is now.
      expect(find.text('Map: 1 lines, 0 gaps, 3 pins'), findsOneWidget);
      expect(find.bySemanticsLabel('12.4 km'), findsOneWidget);
      expect(find.bySemanticsLabel('5h 00m duty'), findsOneWidget);
      expect(find.bySemanticsLabel('Stops, 1'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Call Rahul Das'));
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'tel:9876543210');

      await tester.tap(find.text('Full route'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/days/30'), findsOneWidget);
    });

    testWidgets('Stops opens the timeline and then the full route', (
      WidgetTester tester,
    ) async {
      tall(tester);
      routes.days[30] = day(30, on: at(0), status: DayStatus.onDuty);
      routes.routes[30] = route(30, addresses: const <String?>['Station Rd']);
      routes.initialLive = <LivePosition>[position(1)];
      await pumpPage(
        tester,
        const LivePersonPage(dayId: 30),
        users: people,
        overrides: overrides(),
      );
      await tester.tap(find.bySemanticsLabel('Stops, 1'));
      await tester.pumpAndSettle();
      expect(find.text("Rahul's stops today"), findsOneWidget);
      expect(find.text('1 stop · 0 visits · 12.4 km'), findsOneWidget);
      expect(find.text('Station Rd'), findsOneWidget);
      expect(find.textContaining('Phone was off'), findsOneWidget);

      await tester.tap(find.text('See full day route'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/days/30'), findsOneWidget);
    });

    testWidgets('an old position says no update, a fake one says so', (
      WidgetTester tester,
    ) async {
      routes.days[30] = day(30, on: at(0), status: DayStatus.onDuty);
      routes.routes[30] = route(30);
      routes.initialLive = <LivePosition>[position(20)];
      await pumpPage(
        tester,
        const LivePersonPage(dayId: 30),
        users: people,
        overrides: overrides(),
      );
      expect(find.textContaining('for 20 min · since 8:30 AM'), findsOneWidget);
      expect(find.textContaining('No update'), findsOneWidget);

      routes.live.add(<LivePosition>[position(2, mocked: true)]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Fake GPS'), findsOneWidget);
    });

    testWidgets('after duty off: the end time, no battery', (
      WidgetTester tester,
    ) async {
      routes.days[30] = day(30, on: at(0));
      routes.routes[30] = route(30);
      await pumpPage(
        tester,
        const LivePersonPage(dayId: 30),
        users: people,
        overrides: overrides(),
      );
      expect(find.textContaining('Duty off'), findsOneWidget);
      expect(find.textContaining('at 4:30 PM'), findsOneWidget);
      expect(find.byIcon(DsIcons.battery), findsNothing);
      expect(find.bySemanticsLabel('8h 00m duty'), findsOneWidget);
    });

    for (final double width in <double>[360, 390, 430]) {
      testWidgets('fits ${width.toInt()} wide', (WidgetTester tester) async {
        tester.view.physicalSize = Size(width * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        routes.days[30] = day(30, on: at(0), status: DayStatus.onDuty);
        routes.routes[30] = route(30);
        routes.initialLive = <LivePosition>[position(1, battery: 9)];
        await pumpPage(
          tester,
          const LivePersonPage(dayId: 30),
          users: people,
          overrides: overrides(),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
