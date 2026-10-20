import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/entities/admin_duty_session.dart';
import 'package:diamond_tracking/domain/entities/route_day.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/admin_route_view_page.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/widgets/admin_route_date_pill.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/widgets/admin_route_map_view.dart';
import 'package:diamond_tracking/shared/widgets/app_top_bar.dart';
import 'package:diamond_tracking/shared/widgets/india_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_route.dart';

/// The number shown in one of the stats under the map.
String statValue(WidgetTester tester, String key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
    )
    .first
    .data!;

void main() {
  late FakeRouteRepository repository;
  final today = istDayStartUtc(2026, 10, 17);

  setUp(() => repository = FakeRouteRepository());

  RouteDay dayOf(
    List<AdminDutySession> sessions, {
    List<RoutePoint>? points,
    bool truncated = false,
  }) => RouteDay(
    sessions: sessions,
    points: points ?? routeWalk(),
    serverNow: kRouteNow,
    truncated: truncated,
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    String? dayId,
    VoidCallback? onBack,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: routeOverrides(repository),
        child: MaterialApp(
          theme: AppTheme.light,
          home: AdminRouteViewPage(
            employeeId: 'e1',
            employeeName: 'Asha Patil',
            dayId: dayId,
            onBack: onBack,
          ),
        ),
      ),
    );
    if (settle) {
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
    }
  }

  testWidgets('shows the employee, the day and the date selector', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.byType(AppTopBar), findsOneWidget);
    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Asha Patil · Sat, 17 Oct'), findsOneWidget);
    expect(find.byType(AdminRouteDatePill), findsOneWidget);
    expect(find.byType(AdminRouteMapView), findsOneWidget);
    expect(find.byType(IndiaMap), findsOneWidget);
  });

  testWidgets('back goes back', (tester) async {
    var backed = false;
    await pumpPage(tester, onBack: () => backed = true);

    await tester.tap(find.byKey(const Key('btn-route-back')));

    expect(backed, isTrue);
  });

  group('a day with a route', () {
    setUp(() => repository.days[today] = dayOf([routeSession('s1')]));

    testWidgets('shows the server totals under the map', (tester) async {
      await pumpPage(tester);

      expect(find.byKey(const Key('route-summary-sheet')), findsOneWidget);
      String valueIn(String key) => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(Text),
            ),
          )
          .first
          .data!;
      expect(valueIn('route-stat-distance'), '12.3 km');
      expect(valueIn('route-stat-hours'), '7h 26m');
      expect(valueIn('route-stat-visits'), '2');
      expect(valueIn('route-stat-flagged'), '0');
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Duty hours'), findsOneWidget);
      expect(find.text('8:04 AM – 3:30 PM'), findsOneWidget);
      expect(find.byKey(const Key('route-flag-note')), findsNothing);
      expect(find.byKey(const Key('route-weak-gps-note')), findsNothing);
    });

    testWidgets('explains the markers and offers to show the whole route', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.byKey(const Key('route-legend')), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
      expect(find.text('Now'), findsNothing);
      expect(find.byKey(const Key('btn-route-fit')), findsOneWidget);
    });

    testWidgets('has no playback, speed, scrubber or satellite control', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.textContaining('Satellite'), findsNothing);
      expect(find.byKey(const Key('btn-route-layers')), findsNothing);
      expect(find.text('View visits'), findsNothing);
    });

    testWidgets('names a duty that ended automatically', (tester) async {
      repository.days[today] = dayOf([
        routeSession('s1', status: 'auto_curfew'),
      ]);
      await pumpPage(tester);

      expect(find.text('Duty ended automatically'), findsOneWidget);
    });
  });

  group('today, still on duty', () {
    testWidgets('says hours so far and that the last marker is now', (
      tester,
    ) async {
      repository.days[today] = dayOf([routeSession('s1', open: true, km: 2.1)]);
      await pumpPage(tester);

      expect(find.text('Duty hours so far'), findsOneWidget);
      expect(find.text('On duty now'), findsOneWidget);
      expect(find.text('8:04 AM – now'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('End'), findsNothing);
      expect(find.byKey(const Key('route-distance-unavailable')), findsNothing);
    });

    testWidgets(
      'does not pretend to know a distance the server could not give',
      (tester) async {
        repository.days[today] = dayOf([
          routeSession('s1', open: true, km: null),
        ]);
        await pumpPage(tester);

        expect(
          find.descendant(
            of: find.byKey(const Key('route-stat-distance')),
            matching: find.text('—'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('route-distance-unavailable')),
          findsOneWidget,
        );
      },
    );

    testWidgets('an open session on a past day is not "now"', (tester) async {
      final yesterday = istDayStartUtc(2026, 10, 16);
      repository.days[yesterday] = dayOf([
        routeSession(
          's1',
          open: true,
          startedAt: DateTime.utc(2026, 10, 16, 3),
          km: 1,
        ),
      ]);
      await pumpPage(tester, dayId: '2026-10-16');

      expect(find.text('Now'), findsNothing);
      expect(find.text('End'), findsOneWidget);
    });
  });

  group('flagged points', () {
    testWidgets('are explained in words and left out of the figures', (
      tester,
    ) async {
      repository.days[today] = dayOf(
        [routeSession('s1')],
        points: [
          routePoint(20.0000, 73, 0),
          routePoint(21.0, 74, 5, isMock: true),
          routePoint(20.0001, 73, 10),
          routePoint(20.0002, 73, 20, accuracy: 400),
          routePoint(20.0100, 73, 30),
        ],
      );
      await pumpPage(tester);

      final note = find.byKey(const Key('route-flag-note'));
      expect(note, findsOneWidget);
      expect(
        find.descendant(
          of: note,
          matching: find.textContaining('1 fake-location point is left out'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: note,
          matching: find.textContaining(
            '1 impossible jump not drawn as travel',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Fake location'), findsOneWidget);
      expect(find.text('Weak GPS'), findsOneWidget);
      expect(statValue(tester, 'route-stat-flagged'), '1');
      expect(
        find.descendant(
          of: find.byKey(const Key('route-weak-gps-note')),
          matching: find.textContaining('1 weak GPS reading was left out'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a weak GPS signal alone is calm: no red, no "flagged"', (
      tester,
    ) async {
      repository.days[today] = dayOf(
        [routeSession('s1')],
        points: [
          routePoint(20.0000, 73, 0),
          routePoint(20.0001, 73, 10),
          routePoint(20.0002, 73, 20, accuracy: 400),
        ],
      );
      await pumpPage(tester);

      expect(statValue(tester, 'route-stat-flagged'), '0');
      expect(find.byKey(const Key('route-flag-note')), findsNothing);
      expect(find.byKey(const Key('route-weak-gps-note')), findsOneWidget);
      expect(find.textContaining('flagged'), findsNothing);
      expect(find.text('Weak GPS'), findsOneWidget);
      expect(find.text('Fake location'), findsNothing);
      expect(find.textContaining('This is normal'), findsOneWidget);
    });

    testWidgets('a fake location alone gets the warning and no weak note', (
      tester,
    ) async {
      repository.days[today] = dayOf(
        [routeSession('s1')],
        points: [
          routePoint(20.0000, 73, 0),
          routePoint(21.0, 74, 5, isMock: true),
          routePoint(20.0001, 73, 10),
        ],
      );
      await pumpPage(tester);

      expect(statValue(tester, 'route-stat-flagged'), '1');
      expect(find.byKey(const Key('route-flag-note')), findsOneWidget);
      expect(find.byKey(const Key('route-weak-gps-note')), findsNothing);
      expect(find.text('Fake location'), findsOneWidget);
      expect(find.text('Weak GPS'), findsNothing);
    });

    testWidgets('a single fake-location point reads naturally', (tester) async {
      repository.days[today] = dayOf(
        [routeSession('s1')],
        points: [
          routePoint(20.0000, 73, 0),
          routePoint(21.0, 74, 5, isMock: true),
          routePoint(20.0001, 73, 10),
        ],
      );
      await pumpPage(tester);

      expect(
        find.textContaining('1 fake-location point is left out of the route'),
        findsOneWidget,
      );
    });
  });

  group('states', () {
    testWidgets('loading is shown, not an empty route', (tester) async {
      repository.gate(today);
      await pumpPage(tester, settle: false);
      await tester.pump();

      expect(find.byKey(const Key('route-loading')), findsOneWidget);
      expect(find.text('No location recorded'), findsNothing);
      expect(find.byKey(const Key('route-summary-sheet')), findsNothing);

      repository.release(today);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(find.byKey(const Key('route-loading')), findsNothing);
    });

    testWidgets('a day with no duty says so plainly, with no totals', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('No location recorded'), findsOneWidget);
      expect(
        find.text('No duty points recorded for Sat, 17 Oct.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('route-summary-sheet')), findsNothing);
      expect(find.byKey(const Key('btn-route-fit')), findsNothing);
    });

    testWidgets('duty without a usable location keeps the totals', (
      tester,
    ) async {
      repository.days[today] = dayOf([routeSession('s1')], points: const []);
      await pumpPage(tester);

      expect(find.text('No usable location'), findsOneWidget);
      expect(find.byKey(const Key('route-summary-sheet')), findsOneWidget);
      expect(find.byKey(const Key('route-legend')), findsNothing);
      expect(find.byKey(const Key('btn-route-fit')), findsNothing);
    });

    testWidgets('a day older than 30 days: no route, totals kept', (
      tester,
    ) async {
      repository.days[istDayStartUtc(2026, 9, 10)] = dayOf([
        routeSession(
          's1',
          startedAt: DateTime.utc(2026, 9, 10, 3),
          endedAt: DateTime.utc(2026, 9, 10, 9),
          km: 21.5,
        ),
      ]);
      await pumpPage(tester, dayId: '2026-09-10');

      expect(find.text('Route older than 30 days'), findsOneWidget);
      expect(find.text('21.5 km'), findsOneWidget);
      expect(find.byKey(const Key('route-legend')), findsNothing);
      expect(find.byKey(const Key('btn-route-fit')), findsNothing);
    });

    testWidgets('a failed load is an error with Retry, then recovers', (
      tester,
    ) async {
      repository.error = const NetworkException();
      await pumpPage(tester);

      expect(find.byKey(const Key('route-error')), findsOneWidget);
      expect(find.text("Couldn't load the route"), findsOneWidget);
      expect(find.text('No location recorded'), findsNothing);

      repository.error = null;
      repository.days[today] = dayOf([routeSession('s1')]);
      await tester.tap(find.text('Retry'));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      expect(find.byKey(const Key('route-error')), findsNothing);
      expect(find.byKey(const Key('route-summary-sheet')), findsOneWidget);
    });

    testWidgets('a day cut at the safety cap says so', (tester) async {
      repository.days[today] = dayOf([routeSession('s1')], truncated: true);
      await pumpPage(tester);

      expect(find.byKey(const Key('route-truncated')), findsOneWidget);
    });
  });

  group('the date and reload', () {
    testWidgets('previous and next move the day and load it', (tester) async {
      repository.days[istDayStartUtc(2026, 10, 16)] = dayOf([
        routeSession(
          's1',
          startedAt: DateTime.utc(2026, 10, 16, 3),
          endedAt: DateTime.utc(2026, 10, 16, 9),
          km: 4,
        ),
      ]);
      await pumpPage(tester);
      expect(find.text('Asha Patil · Sat, 17 Oct'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(find.text('Asha Patil · Fri, 16 Oct'), findsOneWidget);
      expect(find.text('4.0 km'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(find.text('Asha Patil · Sat, 17 Oct'), findsOneWidget);
    });

    testWidgets('the reload button reads the day again', (tester) async {
      await pumpPage(tester);
      final calls = repository.calls.length;

      await tester.tap(find.byKey(const Key('btn-route-refresh')));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      expect(repository.calls.length, calls + 1);
    });

    testWidgets('opens on the day it was given', (tester) async {
      await pumpPage(tester, dayId: '2026-10-10');

      expect(find.text('Asha Patil · Sat, 10 Oct'), findsOneWidget);
    });

    testWidgets('opens on today for a day it cannot read', (tester) async {
      await pumpPage(tester, dayId: 'not-a-day');

      expect(find.text('Asha Patil · Sat, 17 Oct'), findsOneWidget);
    });
  });
}
