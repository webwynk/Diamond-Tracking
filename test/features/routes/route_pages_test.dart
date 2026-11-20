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

  DayRoute route(int id, {List<String?> addresses = const <String?>[null]}) =>
      DayRoute(
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
    expect(find.text('Map: 1 lines, 3 pins'), findsOneWidget);
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

  testWidgets('My map is empty before duty on', (WidgetTester tester) async {
    await pumpPage(
      tester,
      const MyMapPage(),
      status: employee,
      overrides: overrides(duty: FakeDutyRepository()),
    );
    expect(find.text('No route today'), findsOneWidget);
  });

  testWidgets('My map shows today\'s route while on duty', (
    WidgetTester tester,
  ) async {
    final DutyDay d = day(9, on: at(0), status: DayStatus.onDuty);
    routes.days[9] = d;
    routes.routes[9] = route(9, addresses: <String?>['Office, Sector V']);

    await pumpPage(
      tester,
      const MyMapPage(),
      status: employee,
      overrides: overrides(duty: FakeDutyRepository(today: d)),
    );
    expect(find.text('Office, Sector V'), findsOneWidget);
    expect(find.text('On duty'), findsOneWidget);
    expect(routes.addressRequests, 0);
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
    expect(find.textContaining('Absent'), findsOneWidget);
    expect(find.textContaining('5.0 km'), findsOneWidget);
    expect(find.byType(HistoryPage), findsOneWidget);

    // The absent day has no route to open.
    await tester.tap(find.textContaining('Absent'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPage), findsOneWidget);

    await tester.tap(find.textContaining('5.0 km'));
    await tester.pumpAndSettle();
    expect(find.text('route /history/day/1'), findsOneWidget);
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
    expect(find.text('Map: 0 lines, 1 pins'), findsOneWidget);
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
