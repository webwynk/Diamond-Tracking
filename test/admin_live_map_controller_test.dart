import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/domain/entities/live_position.dart';
import 'package:diamond_tracking/domain/repositories/live_location_repository.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/map/presentation/controllers/admin_live_map_controller.dart';
import 'package:diamond_tracking/features/admin/map/presentation/controllers/admin_live_map_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_employee_repository.dart';
import 'support/fake_live_locations.dart';

/// Containers a scenario started; disposed when it ends. The framework checks
/// for running timers BEFORE tear-down callbacks run, so `addTearDown` is too
/// late for a controller that owns a periodic timer.
final List<ProviderContainer> opened = <ProviderContainer>[];

void scenario(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      for (final container in opened) {
        container.dispose();
      }
      opened.clear();
    }
  });
}

void main() {
  late FakeLiveLocationRepository live;
  late FakeEmployeeRepository roster;

  setUp(() {
    live = FakeLiveLocationRepository();
    roster = FakeEmployeeRepository(
      roster: [
        rosterEmployee('e-asha', 'Asha Patil', 'DA-101'),
        rosterEmployee('e-ravi', 'Ravi Kumar', 'DA-102'),
        rosterEmployee('e-meena', 'Meena Joshi', 'DA-103'),
      ],
    );
  });

  /// Starts the controller and lets the first load finish.
  Future<ProviderContainer> start(
    WidgetTester tester, {
    DateTime Function()? clock,
  }) async {
    final container = ProviderContainer(
      overrides: liveMapOverrides(live, roster, clock: clock),
    );
    opened.add(container);
    container.listen(adminLiveMapControllerProvider, (_, _) {});
    await settle(tester);
    return container;
  }

  AdminLiveMapState stateOf(ProviderContainer c) =>
      c.read(adminLiveMapControllerProvider);

  group('first load', () {
    scenario('shows loading, never an invented empty map', (tester) async {
      final container = ProviderContainer(
        overrides: liveMapOverrides(live, roster),
      );
      opened.add(container);
      container.listen(adminLiveMapControllerProvider, (_, _) {});

      final before = stateOf(container);
      expect(before.isLoading, isTrue);
      expect(before.officers, isEmpty);
      expect(before.errorMessage, isNull);
      await settle(tester);
    });

    scenario('joins positions with names, ordered by name', (tester) async {
      live.positions = [
        livePosition('e-ravi'),
        livePosition('e-asha', ago: const Duration(minutes: 1)),
      ];
      final container = await start(tester);

      final state = stateOf(container);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.officers.map((o) => o.name), ['Asha Patil', 'Ravi Kumar']);
      expect(state.officers.first.employeeCode, 'DA-101');
      expect(state.officers.first.lastSeen, '1 min ago');
      expect(state.officers.last.lastSeen, 'Just now');
    });

    scenario('a failed first load is an error, and Retry recovers', (
      tester,
    ) async {
      live.error = const NetworkException();
      final container = await start(tester);

      expect(stateOf(container).isLoading, isFalse);
      expect(stateOf(container).errorMessage, isNotNull);
      expect(stateOf(container).officers, isEmpty);
      expect(stateOf(container).connection, LiveConnection.offline);

      live.error = null;
      live.positions = [livePosition('e-asha')];
      container.read(adminLiveMapControllerProvider.notifier).retry();
      await settle(tester);

      expect(stateOf(container).errorMessage, isNull);
      expect(stateOf(container).officers, hasLength(1));
    });

    scenario('still shows positions when the roster cannot be read', (
      tester,
    ) async {
      roster.error = const NetworkException();
      live.positions = [livePosition('e-asha')];
      final container = await start(tester);

      expect(stateOf(container).errorMessage, isNull);
      expect(stateOf(container).officers.single.name, 'Employee');
    });
  });

  group('off duty and refresh', () {
    scenario('off duty is the active staff who are not on duty', (
      tester,
    ) async {
      roster.roster = [
        ...roster.roster,
        const AdminEmployeeItem(
          id: 'e-blocked',
          name: 'Blocked Person',
          employeeCode: 'DA-109',
          phoneNumber: '+919820000109',
          status: AdminEmployeeStatus.blocked,
          isActive: false,
        ),
      ];
      live.positions = [livePosition('e-asha')];
      final container = await start(tester);

      // Three active staff, one on duty; the blocked person is not counted.
      expect(stateOf(container).offDutyCount, 2);

      live.emit(LivePositionChanged(livePosition('e-ravi')));
      await tester.pump(const Duration(seconds: 1));
      expect(stateOf(container).offDutyCount, 1);

      live.emit(const LivePositionRemoved('e-asha'));
      await tester.pump(const Duration(seconds: 1));
      expect(stateOf(container).offDutyCount, 2);
    });

    scenario('is unknown, not zero, when the roster could not be read', (
      tester,
    ) async {
      roster.error = const NetworkException();
      live.positions = [livePosition('e-asha')];
      final container = await start(tester);

      expect(stateOf(container).offDutyCount, isNull);
    });

    scenario('refresh reloads quietly and recovers from an error', (
      tester,
    ) async {
      live.error = const NetworkException();
      final container = await start(tester);
      expect(stateOf(container).errorMessage, isNotNull);

      live
        ..error = null
        ..positions = [livePosition('e-asha')];
      final notifier = container.read(adminLiveMapControllerProvider.notifier);
      final refreshing = notifier.refresh();
      // No loading spinner: a pull to refresh has its own indicator.
      expect(stateOf(container).isLoading, isFalse);
      await refreshing;
      await settle(tester);

      expect(stateOf(container).errorMessage, isNull);
      expect(stateOf(container).officers, hasLength(1));
    });
  });

  group('live changes', () {
    scenario('are applied in one batch per second, not one by one', (
      tester,
    ) async {
      live.positions = [livePosition('e-asha', latitude: 19.0)];
      final container = await start(tester);

      live.emit(
        LivePositionChanged(
          livePosition('e-asha', ago: Duration.zero, latitude: 19.1),
        ),
      );
      live.emit(
        LivePositionChanged(livePosition('e-ravi', ago: Duration.zero)),
      );
      // Nothing has been applied yet.
      expect(stateOf(container).officers, hasLength(1));
      expect(stateOf(container).officers.single.position.latitude, 19.0);

      await tester.pump(const Duration(seconds: 1));
      expect(stateOf(container).officers, hasLength(2));
      expect(
        stateOf(container).officers.first.position.latitude,
        19.1,
        reason: 'Asha moved',
      );
    });

    scenario('an older change never moves someone backwards', (tester) async {
      live.positions = [
        livePosition('e-asha', latitude: 19.0, ago: Duration.zero),
      ];
      final container = await start(tester);

      live.emit(
        LivePositionChanged(
          livePosition(
            'e-asha',
            latitude: 18.0,
            ago: const Duration(minutes: 2),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(stateOf(container).officers.single.position.latitude, 19.0);
    });

    scenario('going off duty removes the person and closes their card', (
      tester,
    ) async {
      live.positions = [livePosition('e-asha'), livePosition('e-ravi')];
      final container = await start(tester);
      container.read(adminLiveMapControllerProvider.notifier).select('e-asha');
      expect(stateOf(container).selectedOfficer?.name, 'Asha Patil');

      live.emit(const LivePositionRemoved('e-asha'));
      await tester.pump(const Duration(seconds: 1));

      expect(stateOf(container).officers.map((o) => o.id), ['e-ravi']);
      expect(stateOf(container).selectedOfficer, isNull);
    });

    scenario('a removal followed by a new duty ends with the new position', (
      tester,
    ) async {
      live.positions = [
        livePosition('e-asha', ago: const Duration(minutes: 30)),
      ];
      final container = await start(tester);

      live.emit(const LivePositionRemoved('e-asha'));
      live.emit(
        LivePositionChanged(livePosition('e-asha', ago: Duration.zero)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(stateOf(container).officers, hasLength(1));
      expect(stateOf(container).officers.single.lastSeen, 'Just now');
    });

    scenario('a person missing from the roster is named after one reload', (
      tester,
    ) async {
      live.positions = [];
      final container = await start(tester);
      expect(roster.calls.where((c) => c == 'getEmployees'), hasLength(1));

      roster.roster = [
        ...roster.roster,
        rosterEmployee('e-new', 'Nita Rao', 'DA-104'),
      ];
      live.positions = [livePosition('e-new')];
      live.emit(LivePositionChanged(livePosition('e-new')));
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);

      expect(stateOf(container).officers.single.name, 'Nita Rao');
      expect(roster.calls.where((c) => c == 'getEmployees'), hasLength(2));
    });

    scenario('a roster that never learns the person is not reloaded forever', (
      tester,
    ) async {
      live.positions = [livePosition('e-ghost')];
      await start(tester);
      // The first load, plus the one retry for the name it did not find.
      final callsAfterLoad = roster.calls.length;
      expect(callsAfterLoad, 2);

      await tester.pump(const Duration(seconds: 5));
      await settle(tester);

      expect(roster.calls.length, callsAfterLoad);
    });
  });

  group('status', () {
    scenario('is judged against the server clock, not the phone clock', (
      tester,
    ) async {
      final serverNow = DateTime.now().toUtc().add(const Duration(minutes: 10));
      live
        ..serverTime = serverNow
        ..positions = [
          // Recorded 3 minutes before the SERVER time.
          livePosition(
            'e-asha',
            ago: const Duration(minutes: 3),
            now: serverNow,
          ),
          // Recorded 8 minutes before the SERVER time.
          livePosition(
            'e-ravi',
            ago: const Duration(minutes: 8),
            now: serverNow,
          ),
          livePosition(
            'e-meena',
            ago: Duration.zero,
            now: serverNow,
            isMock: true,
          ),
        ];
      final container = await start(tester);

      final byName = {for (final o in stateOf(container).officers) o.name: o};
      expect(byName['Asha Patil']!.status, LiveStatus.active);
      expect(byName['Ravi Kumar']!.status, LiveStatus.stale);
      expect(byName['Meena Joshi']!.status, LiveStatus.suspect);
      expect(stateOf(container).onDutyCount, 1);
      expect(stateOf(container).staleCount, 1);
      expect(stateOf(container).needsCheckCount, 1);
    });

    scenario('a quiet phone turns stale as time passes', (tester) async {
      // The test clock stands in for both the phone and the server clock.
      var current = DateTime.now().toUtc();
      live
        ..serverTime = current
        ..positions = [
          livePosition('e-asha', ago: const Duration(minutes: 4), now: current),
        ];
      final container = await start(tester, clock: () => current);
      expect(stateOf(container).officers.single.status, LiveStatus.active);

      current = current.add(const Duration(seconds: 90));
      live.serverTime = current;
      await tester.pump(const Duration(seconds: 90));

      expect(stateOf(container).officers.single.status, LiveStatus.stale);
      expect(stateOf(container).officers.single.lastSeen, '5 min ago');
    });
  });

  group('connection', () {
    scenario('moves connecting -> live -> offline -> live', (tester) async {
      live.positions = [livePosition('e-asha')];
      final container = await start(tester);
      expect(stateOf(container).connection, LiveConnection.connecting);

      live.emit(const LiveConnectionChanged(connected: true));
      expect(stateOf(container).connection, LiveConnection.live);

      live.emit(const LiveConnectionChanged(connected: false));
      expect(stateOf(container).connection, LiveConnection.offline);

      live.emit(const LiveConnectionChanged(connected: true));
      expect(stateOf(container).connection, LiveConnection.live);
    });

    scenario('coming back up reloads the full list (changes may be missed)', (
      tester,
    ) async {
      live.positions = [livePosition('e-asha')];
      final container = await start(tester);
      final loads = live.fetchCount;

      live.positions = [livePosition('e-asha'), livePosition('e-ravi')];
      live.emit(const LiveConnectionChanged(connected: true));
      await settle(tester);

      expect(live.fetchCount, loads + 1);
      expect(stateOf(container).officers, hasLength(2));
    });

    scenario('a failed background reload keeps the map and says offline', (
      tester,
    ) async {
      live.positions = [livePosition('e-asha')];
      final container = await start(tester);
      live.emit(const LiveConnectionChanged(connected: true));
      await settle(tester);
      expect(stateOf(container).connection, LiveConnection.live);

      live.error = const NetworkException();
      await tester.pump(const Duration(seconds: 60));
      await settle(tester);

      expect(stateOf(container).officers, hasLength(1));
      expect(stateOf(container).errorMessage, isNull);
      expect(stateOf(container).connection, LiveConnection.offline);

      live.error = null;
      await tester.pump(const Duration(seconds: 60));
      await settle(tester);
      expect(stateOf(container).connection, LiveConnection.live);
    });

    scenario('reloads the full list every minute as a safety net', (
      tester,
    ) async {
      live.positions = [livePosition('e-asha')];
      await start(tester);
      final loads = live.fetchCount;

      await tester.pump(const Duration(seconds: 60));
      await settle(tester);

      expect(live.fetchCount, loads + 1);
    });
  });

  group('filters', () {
    scenario('status filter and search narrow what is drawn', (tester) async {
      live.positions = [
        livePosition('e-asha'),
        livePosition('e-ravi', ago: const Duration(minutes: 9)),
        livePosition('e-meena', isMock: true),
      ];
      final container = await start(tester);
      final notifier = container.read(adminLiveMapControllerProvider.notifier);

      expect(stateOf(container).filteredOfficers, hasLength(3));

      notifier.setFilter(AdminMapFilter.stale);
      expect(stateOf(container).filteredOfficers.single.name, 'Ravi Kumar');

      notifier.setFilter(AdminMapFilter.needsCheck);
      expect(stateOf(container).filteredOfficers.single.name, 'Meena Joshi');

      notifier.setFilter(AdminMapFilter.all);
      notifier.setSearchQuery('da-101');
      expect(stateOf(container).filteredOfficers.single.name, 'Asha Patil');

      notifier.setSearchQuery('kumar');
      expect(stateOf(container).filteredOfficers.single.name, 'Ravi Kumar');

      notifier.setFilter(AdminMapFilter.onDuty);
      expect(stateOf(container).filteredOfficers, isEmpty);

      notifier.clearFilters();
      expect(stateOf(container).filteredOfficers, hasLength(3));
      expect(stateOf(container).hasActiveFilter, isFalse);
    });
  });

  group('the controller stops with its provider', () {
    scenario(
      'leaving the screen closes the feed (sign-out leaves nothing open)',
      (tester) async {
        live.positions = [livePosition('e-asha')];
        final container = ProviderContainer(
          overrides: liveMapOverrides(live, roster),
        );
        opened.add(container);
        final subscription = container.listen(
          adminLiveMapControllerProvider,
          (_, _) {},
        );
        await settle(tester);
        expect(live.hasListener, isTrue);

        subscription.close();
        await tester.pump(const Duration(milliseconds: 100));

        expect(live.hasListener, isFalse);
        final loads = live.fetchCount;
        await tester.pump(const Duration(minutes: 3));
        expect(live.fetchCount, loads);
      },
    );

    scenario('no timer is left running after dispose', (tester) async {
      live.positions = [livePosition('e-asha')];
      final container = ProviderContainer(
        overrides: liveMapOverrides(live, roster),
      );
      container.listen(adminLiveMapControllerProvider, (_, _) {});
      await settle(tester);

      container.dispose();
      final loads = live.fetchCount;
      await tester.pump(const Duration(minutes: 3));

      expect(live.fetchCount, loads);
    });
  });
}

/// Lets queued async work finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}
