import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/repositories/live_location_repository.dart';
import 'package:diamond_tracking/features/admin/map/presentation/admin_live_map_page.dart';
import 'package:diamond_tracking/features/admin/map/presentation/widgets/admin_map_filter_chips_bar.dart';
import 'package:diamond_tracking/features/admin/map/presentation/widgets/admin_map_floating_controls.dart';
import 'package:diamond_tracking/features/admin/map/presentation/widgets/admin_map_search_bar.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/admin_route_view_page.dart';
import 'package:diamond_tracking/shared/widgets/app_top_bar.dart';
import 'package:diamond_tracking/shared/widgets/india_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_employee_repository.dart';
import 'support/fake_live_locations.dart';
import 'support/fake_notification_repository.dart';
import 'support/fake_route.dart';

void main() {
  late FakeLiveLocationRepository live;
  late FakeEmployeeRepository roster;
  late FakeRouteRepository routes;

  setUp(() {
    routes = FakeRouteRepository();
    live = FakeLiveLocationRepository();
    roster = FakeEmployeeRepository(
      roster: [
        rosterEmployee('e-asha', 'Asha Patil', 'DA-101'),
        rosterEmployee('e-ravi', 'Ravi Kumar', 'DA-102'),
        rosterEmployee('e-meena', 'Meena Joshi', 'DA-103'),
      ],
    );
  });

  /// One employee in each status: Asha active, Ravi stale, Meena suspect.
  void threePeople() {
    live.positions = [
      livePosition('e-asha'),
      livePosition('e-ravi', ago: const Duration(minutes: 9)),
      livePosition('e-meena', isMock: true),
    ];
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    VoidCallback? onNavigateToNotifications,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...liveMapOverrides(live, roster),
          notificationOverride(FakeNotificationRepository()),
          ...routeOverrides(routes),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AdminLiveMapPage(
            onNavigateToNotifications: onNavigateToNotifications,
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

  /// The live map owns a timer, so the page is taken down before the test ends
  /// (the framework checks for running timers before tear-down callbacks).
  Future<void> closePage(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  Future<void> openList(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('btn-admin-map-list-view')));
    await tester.pumpAndSettle();
  }

  group('Screen 15 AdminLiveMapPage', () {
    testWidgets('shows the title and opens notifications', (tester) async {
      var opened = false;
      await pumpPage(tester, onNavigateToNotifications: () => opened = true);

      expect(find.byType(AppTopBar), findsOneWidget);
      expect(find.text('Live Map'), findsOneWidget);
      expect(find.text('Diamond Agritech'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('btn-telemetry-notifications-action')),
      );
      await tester.pump();
      expect(opened, isTrue);
      await closePage(tester);
    });

    testWidgets(
      'draws the map, search bar, chips with real counts, and tools',
      (tester) async {
        threePeople();
        await pumpPage(tester);

        expect(find.byType(IndiaMap), findsOneWidget);
        expect(find.byType(AdminMapSearchBar), findsOneWidget);
        expect(find.byType(AdminMapFloatingControls), findsOneWidget);
        expect(find.byType(AdminMapFilterChipsBar), findsOneWidget);
        expect(find.text('All 3'), findsOneWidget);
        expect(find.text('On duty 1'), findsOneWidget);
        expect(find.text('Stale 1'), findsOneWidget);
        expect(find.text('Check 1'), findsOneWidget);
        // Off-duty and blocked people have no position, so no such chips.
        expect(find.textContaining('Off '), findsNothing);
        expect(find.textContaining('Blocked'), findsNothing);
        // No satellite toggle on a street-only map.
        expect(find.byKey(const Key('btn-admin-map-layers')), findsNothing);
        await closePage(tester);
      },
    );

    testWidgets('shows a loading indicator, not an empty map, while loading', (
      tester,
    ) async {
      await pumpPage(tester, settle: false);

      expect(find.byKey(const Key('live-map-loading')), findsOneWidget);
      expect(find.text('No one is on duty'), findsNothing);

      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(find.byKey(const Key('live-map-loading')), findsNothing);
      await closePage(tester);
    });

    testWidgets('says plainly when nobody is on duty', (tester) async {
      await pumpPage(tester);

      expect(find.text('No one is on duty'), findsOneWidget);
      expect(find.text('All 0'), findsOneWidget);
      await closePage(tester);
    });

    testWidgets('a failed load is an error with Retry, then recovers', (
      tester,
    ) async {
      live.error = const NetworkException();
      await pumpPage(tester);

      expect(find.text("Couldn't load the live map"), findsOneWidget);
      expect(find.text('No one is on duty'), findsNothing);

      live
        ..error = null
        ..positions = [livePosition('e-asha')];
      await tester.tap(find.text('Retry'));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      expect(find.text("Couldn't load the live map"), findsNothing);
      expect(find.text('All 1'), findsOneWidget);
      await closePage(tester);
    });

    testWidgets('the connection badge tells live from offline', (tester) async {
      threePeople();
      await pumpPage(tester);
      expect(find.text('Connecting…'), findsOneWidget);

      live.emit(const LiveConnectionChanged(connected: true));
      await tester.pump();
      expect(find.text('Live'), findsOneWidget);

      live.emit(const LiveConnectionChanged(connected: false));
      await tester.pump();
      expect(
        find.text('Offline · showing last known positions'),
        findsOneWidget,
      );
      await closePage(tester);
    });

    testWidgets('a position that arrives appears without any reload', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text('All 0'), findsOneWidget);

      live.emit(LivePositionChanged(livePosition('e-asha')));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('All 1'), findsOneWidget);
      expect(find.text('No one is on duty'), findsNothing);
      await closePage(tester);
    });
  });

  group('list alternative and the employee card', () {
    testWidgets(
      'lists everyone on duty with a status label, not colour alone',
      (tester) async {
        threePeople();
        await pumpPage(tester);
        await openList(tester);

        expect(find.text('On duty now (3)'), findsOneWidget);
        expect(find.text('Asha Patil'), findsOneWidget);
        expect(find.text('Ravi Kumar'), findsOneWidget);
        expect(find.text('Meena Joshi'), findsOneWidget);
        expect(find.text('DA-101 · Just now'), findsOneWidget);
        expect(find.text('DA-102 · 9 min ago'), findsOneWidget);
        expect(find.text('On duty'), findsOneWidget);
        expect(find.text('No update 5 min'), findsOneWidget);
        expect(find.text('Check needed'), findsOneWidget);
        await closePage(tester);
      },
    );

    testWidgets('picking a person opens their card; Close hides it', (
      tester,
    ) async {
      threePeople();
      await pumpPage(tester);
      expect(find.byKey(const Key('live-officer-card')), findsNothing);

      await openList(tester);
      await tester.tap(find.byKey(const Key('live-officer-row-e-ravi')));
      await tester.pumpAndSettle();

      final card = find.byKey(const Key('live-officer-card'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Ravi Kumar')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('DA-102')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('No update 5 min')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('9 min ago')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('80%')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('±6 m')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('btn-live-officer-close')));
      await tester.pump();
      expect(find.byKey(const Key('live-officer-card')), findsNothing);
      await closePage(tester);
    });

    testWidgets('View route opens the route of that employee', (tester) async {
      threePeople();
      await pumpPage(tester);
      await openList(tester);
      await tester.tap(find.byKey(const Key('live-officer-row-e-ravi')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn-live-officer-route')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminRouteViewPage), findsOneWidget);
      expect(find.textContaining('Ravi Kumar'), findsWidgets);
      expect(routes.calls.single.employeeId, 'e-ravi');
      await closePage(tester);
    });

    testWidgets('the card closes by itself when that person goes off duty', (
      tester,
    ) async {
      threePeople();
      await pumpPage(tester);
      await openList(tester);
      await tester.tap(find.byKey(const Key('live-officer-row-e-asha')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live-officer-card')), findsOneWidget);

      live.emit(const LivePositionRemoved('e-asha'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const Key('live-officer-card')), findsNothing);
      expect(find.text('All 2'), findsOneWidget);
      await closePage(tester);
    });

    testWidgets('a chip narrows the list; search narrows it further', (
      tester,
    ) async {
      threePeople();
      await pumpPage(tester);

      await tester.tap(find.byKey(const Key('chip-admin-map-stale')));
      await tester.pump();
      await openList(tester);
      expect(find.text('On duty now (1)'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Asha Patil'), findsNothing);
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chip-admin-map-all')));
      await tester.enterText(
        find.byKey(const Key('input-admin-map-search')),
        'da-103',
      );
      await tester.pump();
      await openList(tester);
      expect(find.text('On duty now (1)'), findsOneWidget);
      expect(find.text('Meena Joshi'), findsOneWidget);
      await closePage(tester);
    });

    testWidgets('filtering everyone out says so and Clear filters restores', (
      tester,
    ) async {
      threePeople();
      await pumpPage(tester);

      await tester.enterText(
        find.byKey(const Key('input-admin-map-search')),
        'zzz',
      );
      await tester.pump();
      expect(find.text('No results for these filters'), findsOneWidget);
      expect(find.text('No one is on duty'), findsNothing);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.text('No results for these filters'), findsNothing);
      expect(find.text('All 3'), findsOneWidget);
      await closePage(tester);
    });

    testWidgets('the list explains itself when nobody is on duty', (
      tester,
    ) async {
      await pumpPage(tester);
      await openList(tester);

      expect(find.text('On duty now (0)'), findsOneWidget);
      expect(find.text('No one is on duty'), findsWidgets);
      await closePage(tester);
    });

    testWidgets('the zoom tools do nothing harmful without a native map', (
      tester,
    ) async {
      threePeople();
      await pumpPage(tester);

      await tester.tap(find.byKey(const Key('btn-admin-map-recenter')));
      await tester.pump();
      expect(find.byKey(const Key('btn-admin-map-recenter')), findsOneWidget);
      await closePage(tester);
    });
  });
}
