import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/routes/application/route_providers.dart';
import 'package:diamond_tracking/features/routes/domain/day_route.dart';
import 'package:diamond_tracking/features/routes/domain/geo_point.dart';
import 'package:diamond_tracking/features/routes/domain/live_position.dart';
import 'package:diamond_tracking/features/routes/presentation/live_map_page.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:diamond_tracking/features/visits/domain/visit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  // 2026-11-20 13:30 IST.
  final DateTime now = DateTime.utc(2026, 11, 20, 8);
  DateTime at(int min) =>
      DateTime.utc(2026, 11, 20, 3).add(Duration(minutes: min));
  DateTime ago(int min) => now.subtract(Duration(minutes: min));
  final DateTime today = DateTime.utc(2026, 11, 20);

  late FakeRouteRepository routes;
  late FakeVisitsRepository visits;
  setUp(() {
    routes = FakeRouteRepository();
    visits = FakeVisitsRepository();
  });

  List<Override> overrides() => <Override>[
    routeRepositoryProvider.overrideWithValue(routes),
    showGoogleMapProvider.overrideWithValue(false),
    serverClockProvider.overrideWithValue(FixedClock(now).clock),
  ];

  final FakeUsersRepository people = FakeUsersRepository(<Profile>[
    profile('r', code: 'EMP001', name: 'Rahul Das'),
    profile('s', code: 'EMP002', name: 'Sourav Mondal'),
    profile('k', code: 'EMP003', name: 'Kunal Paul'),
    profile('g', code: 'EMP009', name: 'Subhajit Ghosh'),
  ]);

  DutyDay day(int id, String user, {bool done = false, int? km}) => DutyDay(
    id: id,
    userId: user,
    day: today,
    status: done ? DayStatus.present : DayStatus.onDuty,
    dutyOnAt: at(12),
    dutyOffAt: done ? at(185) : null,
    workedMinutes: done ? 173 : null,
    distanceM: km,
  );

  LivePosition pos(
    int dayId,
    String user, {
    required int minAgo,
    int? battery,
    bool mocked = false,
  }) => LivePosition(
    userId: user,
    dutyDayId: dayId,
    point: GeoPoint(22.7 + dayId / 100, 88.4),
    recordedAt: ago(minAgo),
    battery: battery,
    mocked: mocked,
  );

  /// Rahul live, Sourav no update for 12 min, Kunal fake GPS, Subhajit
  /// finished.
  void fillTeam() {
    routes.days[20] = day(20, 'r', km: 42600);
    routes.days[21] = day(21, 's', km: 29000);
    routes.days[22] = day(22, 'k', km: 22000);
    routes.days[23] = day(23, 'g', done: true, km: 18000);
    routes.initialLive = <LivePosition>[
      pos(20, 'r', minAgo: 1, battery: 64),
      pos(21, 's', minAgo: 12, battery: 18),
      pos(22, 'k', minAgo: 2, battery: 41, mocked: true),
      pos(23, 'g', minAgo: 200, battery: 38),
    ];
  }

  Future<void> show(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpPage(
      tester,
      const LiveMapPage(),
      users: people,
      visits: visits,
      overrides: overrides(),
    );
  }

  testWidgets('everyone: pins, chips and the needs-attention cards', (
    WidgetTester tester,
  ) async {
    fillTeam();
    await show(tester);

    // Finished people are not pinned unless that chip is picked.
    expect(find.text('Map: 0 lines, 0 gaps, 3 pins'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Open team list, 2 need attention'),
      findsOneWidget,
    );
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Swipe for more'), findsOneWidget);
    expect(find.text('Sourav Mondal'), findsOneWidget);
    expect(find.text('No update · 12 min'), findsOneWidget);
    expect(find.text('18% battery · 29.0 km'), findsOneWidget);

    await tester.drag(find.text('Sourav Mondal'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Kunal Paul'), findsOneWidget);
    expect(find.text('Fake GPS · at 1:28 PM'), findsOneWidget);
    expect(find.text('Location may be false · 22.0 km'), findsOneWidget);
  });

  testWidgets('the chips filter the pins, tapping again shows all', (
    WidgetTester tester,
  ) async {
    fillTeam();
    await show(tester);

    await tester.ensureVisible(find.text('Finished'));
    await tester.tap(find.text('Finished'));
    await tester.pumpAndSettle();
    expect(find.text('Map: 0 lines, 0 gaps, 1 pins'), findsOneWidget);

    await tester.tap(find.text('No update'));
    await tester.pumpAndSettle();
    expect(find.text('Map: 0 lines, 0 gaps, 2 pins'), findsOneWidget);

    await tester.tap(find.text('No update'));
    await tester.pumpAndSettle();
    expect(find.text('Map: 0 lines, 0 gaps, 3 pins'), findsOneWidget);
  });

  testWidgets('search by name shows matches and opens a person', (
    WidgetTester tester,
  ) async {
    fillTeam();
    await show(tester);

    await tester.enterText(find.byType(TextField), 'rah');
    await tester.pumpAndSettle();
    expect(find.text('Map: 0 lines, 0 gaps, 1 pins'), findsOneWidget);
    expect(find.text('Rahul Das'), findsOneWidget);
    expect(find.text('1 min ago'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(
      find.text("Nobody on today's duty list has that name."),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'rah');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rahul Das'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Back to everyone'), findsOneWidget);
    expect(find.text('Full route'), findsOneWidget);
  });

  testWidgets('the team list groups, filters and searches by ID', (
    WidgetTester tester,
  ) async {
    fillTeam();
    await show(tester);

    await tester.tap(find.bySemanticsLabel(RegExp('Open team list')));
    await tester.pumpAndSettle();
    expect(find.text("Today's team"), findsOneWidget);
    expect(find.text('3 on duty, 1 finished · tap a name'), findsOneWidget);
    expect(find.text('NEEDS ATTENTION · 2'), findsOneWidget);
    expect(find.text('LIVE · 1'), findsOneWidget);
    expect(find.text('FINISHED · 1'), findsOneWidget);
    expect(find.text('Duty off 11:35 AM'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('18%')),
      findsOneWidget,
    );

    final Finder drawerSearch = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(TextField),
    );
    await tester.enterText(drawerSearch, 'emp009');
    await tester.pumpAndSettle();
    expect(find.text('FINISHED · 1'), findsOneWidget);
    expect(find.text('LIVE · 1'), findsNothing);

    await tester.enterText(drawerSearch, '');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('Live')),
    );
    await tester.pumpAndSettle();
    expect(find.text('NEEDS ATTENTION · 2'), findsNothing);

    await tester.tap(find.text('Rahul Das'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Full route'), findsOneWidget);
  });

  testWidgets('a person: route, figures, stops sheet and full route', (
    WidgetTester tester,
  ) async {
    fillTeam();
    routes.routes[20] = DayRoute(
      dayId: 20,
      segments: const <List<GeoPoint>>[
        <GeoPoint>[GeoPoint(22.5, 88.3), GeoPoint(22.6, 88.4)],
      ],
      stops: <RouteStop>[
        RouteStop(
          point: const GeoPoint(22.55, 88.35),
          start: at(65),
          end: at(100),
          address: 'Krishi Kendra Rd, Barasat',
        ),
      ],
      notes: const <RouteNote>[],
      distanceM: 42600,
      pointCount: 80,
    );
    visits.byDay[20] = <Visit>[
      Visit(
        id: 'v1',
        storeName: 'Maa Tara Agro',
        fromGallery: false,
        capturedAt: at(70),
      ),
      Visit(
        id: 'v2',
        storeName: 'Ghosh Seeds',
        fromGallery: false,
        capturedAt: at(200),
      ),
    ];
    await show(tester);

    await tester.tap(find.bySemanticsLabel(RegExp('Open team list')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rahul Das'));
    await tester.pumpAndSettle();

    // Start, 1 stop, 2 visits without a place, and Rahul's pin.
    expect(find.text('Map: 1 lines, 0 gaps, 3 pins'), findsOneWidget);
    expect(find.text('RD'), findsOneWidget);
    expect(
      find.text('Live · 1 min ago · since 8:42 AM', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('42.6 km'), findsOneWidget);
    expect(find.text('4h 48m'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel('Centre on Rahul'), findsOneWidget);

    await tester.tap(find.text('Stops 1'));
    await tester.pumpAndSettle();
    expect(find.text("Rahul's stops today"), findsOneWidget);
    expect(find.text('1 stop · 2 visits · 42.6 km'), findsOneWidget);
    expect(find.text('Krishi Kendra Rd, Barasat'), findsOneWidget);

    await tester.ensureVisible(find.text('See full day route'));
    await tester.tap(find.text('See full day route'));
    await tester.pumpAndSettle();
    expect(find.text('route /admin/days/20'), findsOneWidget);
  });

  testWidgets('back to everyone, and a late position moves someone to '
      'needs attention', (WidgetTester tester) async {
    fillTeam();
    await show(tester);

    await tester.tap(find.text('Sourav Mondal'));
    await tester.pumpAndSettle();
    expect(
      find.text('No update · 12 min · since 8:42 AM', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Back to everyone'));
    await tester.pumpAndSettle();
    expect(find.text('Needs attention'), findsOneWidget);

    routes.live.add(<LivePosition>[
      pos(20, 'r', minAgo: 9, battery: 60),
      pos(21, 's', minAgo: 12, battery: 18),
      pos(22, 'k', minAgo: 2, battery: 41, mocked: true),
    ]);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Open team list, 3 need attention'),
      findsOneWidget,
    );
  });

  testWidgets('nobody on duty yet', (WidgetTester tester) async {
    await show(tester);
    expect(find.text('Nobody on duty yet'), findsOneWidget);
    expect(find.text('Needs attention'), findsNothing);
  });

  testWidgets('a load error offers to try again', (WidgetTester tester) async {
    fillTeam();
    routes.daysOnError = Exception('offline');
    await show(tester);
    expect(find.text('Could not load'), findsOneWidget);

    routes.daysOnError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Needs attention'), findsOneWidget);
  });

  test('the line under a name and the reload times', () {
    final LiveRow fresh = LiveRow(
      name: 'Rahul Das',
      code: 'EMP001',
      day: day(20, 'r'),
      position: pos(20, 'r', minAgo: 0),
      state: LiveState.live,
    );
    expect(liveLine(fresh, now), 'Just now');
    final LiveRow none = LiveRow(
      name: 'Sourav Mondal',
      code: 'EMP002',
      day: day(21, 's'),
      position: null,
      state: LiveState.stale,
    );
    expect(liveLine(none, now), 'No location yet');
    expect(none.battery, '–');
    expect(none.matches('emp002'), isTrue);
    expect(personReloadMinutes, 2);
  });

  for (final double width in <double>[360, 390, 430]) {
    testWidgets('fits a $width wide phone: map, team list, person', (
      WidgetTester tester,
    ) async {
      fillTeam();
      await show(tester, width: width);
      expect(tester.takeException(), isNull);

      await tester.tap(find.bySemanticsLabel(RegExp('Open team list')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Kunal Paul'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Full route'), findsOneWidget);
    });
  }
}
