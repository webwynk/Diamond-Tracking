import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/domain/entities/admin_duty_session.dart';
import 'package:diamond_tracking/domain/entities/route_day.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/controllers/admin_route_view_controller.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/controllers/admin_route_view_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_route.dart';

void main() {
  late FakeRouteRepository repository;
  final today = istDayStartUtc(2026, 10, 17);

  setUp(() => repository = FakeRouteRepository());

  const args = RouteViewArgs(employeeId: 'e1');

  ProviderContainer open([RouteViewArgs a = args]) {
    final container = ProviderContainer(overrides: routeOverrides(repository));
    addTearDown(container.dispose);
    container.listen(adminRouteViewControllerProvider(a), (_, _) {});
    return container;
  }

  AdminRouteViewState stateOf(ProviderContainer c, [RouteViewArgs a = args]) =>
      c.read(adminRouteViewControllerProvider(a));

  AdminRouteViewNotifier notifierOf(
    ProviderContainer c, [
    RouteViewArgs a = args,
  ]) => c.read(adminRouteViewControllerProvider(a).notifier);

  RouteDay dayOf(
    List<AdminDutySession> sessions, {
    List<RoutePoint>? points,
    DateTime? serverNow,
  }) => RouteDay(
    sessions: sessions,
    points: points ?? routeWalk(),
    serverNow: serverNow ?? kRouteNow,
  );

  group('opening', () {
    test(
      'starts on today (IST) for this employee, loading, never an invented route',
      () async {
        final container = open();

        final before = stateOf(container);
        expect(before.load, RouteLoad.loading);
        expect(before.selectedDate, DateTime(2026, 10, 17));
        expect(before.selectedDateText, 'Sat, 17 Oct');
        expect(before.summary, isNull);
        expect(before.day, isNull);

        await pumpEventQueue();

        expect(repository.calls, hasLength(1));
        final call = repository.calls.single;
        expect(call.employeeId, 'e1');
        expect(
          call.dayStartUtc,
          today,
          reason: '00:00 IST is 18:30 UTC the day before',
        );
        expect(call.dayEndUtc, today.add(const Duration(days: 1)));
        expect(call.withPoints, isTrue);
      },
    );

    test('opens on the day it was asked for', () async {
      final container = open(
        RouteViewArgs(
          employeeId: 'e1',
          initialDate: DateTime(2026, 10, 10, 15),
        ),
      );

      await pumpEventQueue();

      expect(repository.calls.single.dayStartUtc, istDayStartUtc(2026, 10, 10));
      expect(
        stateOf(
          container,
          RouteViewArgs(
            employeeId: 'e1',
            initialDate: DateTime(2026, 10, 10, 15),
          ),
        ).selectedDateText,
        'Sat, 10 Oct',
      );
    });

    test('a different employee is a different screen state', () async {
      final container = open();
      await pumpEventQueue();

      const other = RouteViewArgs(employeeId: 'e2');
      container.listen(adminRouteViewControllerProvider(other), (_, _) {});
      await pumpEventQueue();

      expect(repository.calls.map((c) => c.employeeId), ['e1', 'e2']);
    });
  });

  group('the summary is the server figures', () {
    test(
      'one finished session: stored km, its hours, visits, shift range',
      () async {
        repository.days[today] = dayOf([routeSession('s1')]);
        final container = open();
        await pumpEventQueue();

        final state = stateOf(container);
        final summary = state.summary!;
        expect(state.load, RouteLoad.loaded);
        expect(summary.distanceKm, 12.345);
        expect(summary.dutyDuration, const Duration(hours: 7, minutes: 26));
        expect(summary.visitsCount, 2);
        expect(summary.sessionCount, 1);
        expect(summary.shiftTimeRange, '8:04 AM – 3:30 PM');
        expect(summary.endNote, isNull);
        expect(summary.hasOpenSession, isFalse);
        expect(state.isToday, isTrue);
      },
    );

    test(
      'an open session runs to the SERVER clock, not the phone clock',
      () async {
        // The phone says 10:00 IST; the server says 12:04 IST (2 h earlier on the phone).
        final serverNow = DateTime.utc(2026, 10, 17, 6, 34);
        repository.days[today] = dayOf([
          routeSession('s1', open: true, km: 3.2),
        ], serverNow: serverNow);
        final container = open();
        await pumpEventQueue();

        final summary = stateOf(container).summary!;
        expect(summary.dutyDuration, const Duration(hours: 4));
        expect(summary.shiftTimeRange, '8:04 AM – now');
        expect(summary.endNote, 'On duty now');
        expect(summary.hasOpenSession, isTrue);
        expect(summary.distanceKm, 3.2);
      },
    );

    test(
      'an open session whose running distance is unknown shows no distance',
      () async {
        repository.days[today] = dayOf([
          routeSession('s1', open: true, km: null),
        ]);
        final container = open();
        await pumpEventQueue();

        expect(stateOf(container).summary!.distanceKm, isNull);
      },
    );

    test(
      'several sessions add up, and one unknown distance makes the total unknown',
      () async {
        repository.days[today] = dayOf([
          routeSession(
            's1',
            startedAt: DateTime.utc(2026, 10, 17, 2, 34),
            endedAt: DateTime.utc(2026, 10, 17, 4, 34),
            km: 5,
            visits: 1,
          ),
          routeSession(
            's2',
            status: 'auto_curfew',
            startedAt: DateTime.utc(2026, 10, 17, 6, 34),
            endedAt: DateTime.utc(2026, 10, 17, 8, 4),
            km: 2.5,
            visits: 3,
          ),
        ]);
        final container = open();
        await pumpEventQueue();

        final summary = stateOf(container).summary!;
        expect(summary.sessionCount, 2);
        expect(summary.distanceKm, 7.5);
        expect(summary.dutyDuration, const Duration(hours: 3, minutes: 30));
        expect(summary.visitsCount, 4);
        expect(summary.shiftTimeRange, '8:04 AM – 1:34 PM');
        expect(summary.endNote, 'Duty ended automatically');

        repository.days[today] = dayOf([
          routeSession('s1', km: 5),
          routeSession(
            's2',
            km: null,
            startedAt: DateTime.utc(2026, 10, 17, 6, 34),
            endedAt: DateTime.utc(2026, 10, 17, 8, 4),
          ),
        ]);
        await notifierOf(container).reload();
        expect(stateOf(container).summary!.distanceKm, isNull);
      },
    );

    test('a block that ended duty is said so', () async {
      repository.days[today] = dayOf([routeSession('s1', status: 'blocked')]);
      final container = open();
      await pumpEventQueue();

      expect(stateOf(container).summary!.endNote, 'Employee was blocked');
    });

    test(
      'flagged points and jumps are counted from the stored points',
      () async {
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
        final container = open();
        await pumpEventQueue();

        final summary = stateOf(container).summary!;
        expect(summary.flaggedPoints, 2);
        expect(summary.jumpCount, 1);
        expect(stateOf(container).analysis!.mockPoints, hasLength(1));
      },
    );
  });

  group('states', () {
    test('a day with no duty is "no duty", not a broken route', () async {
      final container = open();
      await pumpEventQueue();

      final state = stateOf(container);
      expect(state.load, RouteLoad.loaded);
      expect(state.summary, isNull);
      expect(state.hasNoDuty, isTrue);
      expect(state.hasNoRoute, isFalse);
    });

    test(
      'duty with no usable point is its own state, and keeps the totals',
      () async {
        repository.days[today] = dayOf([routeSession('s1')], points: const []);
        final container = open();
        await pumpEventQueue();

        final state = stateOf(container);
        expect(state.hasNoRoute, isTrue);
        expect(state.hasNoDuty, isFalse);
        expect(state.summary, isNotNull);
      },
    );

    test(
      'only fake points: nothing to draw as a line, but the flags still show',
      () async {
        repository.days[today] = dayOf(
          [routeSession('s1')],
          points: [routePoint(20, 73, 0, isMock: true)],
        );
        final container = open();
        await pumpEventQueue();

        expect(stateOf(container).hasNoRoute, isFalse);
        expect(stateOf(container).analysis!.hasAnythingToDraw, isTrue);
      },
    );

    test('a failed load is an error that reload recovers from', () async {
      repository.error = const NetworkException();
      final container = open();
      await pumpEventQueue();

      expect(stateOf(container).load, RouteLoad.failed);
      expect(stateOf(container).errorMessage, isNotNull);
      expect(stateOf(container).summary, isNull);

      repository.error = null;
      repository.days[today] = dayOf([routeSession('s1')]);
      await notifierOf(container).reload();

      expect(stateOf(container).load, RouteLoad.loaded);
      expect(stateOf(container).errorMessage, isNull);
      expect(stateOf(container).summary, isNotNull);
    });

    test('an unexpected failure gets a plain message, not its text', () async {
      repository.error = const FormatException('secret details');
      final container = open();
      await pumpEventQueue();

      expect(stateOf(container).load, RouteLoad.failed);
      expect(stateOf(container).errorMessage, isNot(contains('secret')));
    });
  });

  group('the date', () {
    test('cannot go past today', () async {
      final container = open();
      await pumpEventQueue();

      notifierOf(container).nextDate();
      await pumpEventQueue();

      expect(stateOf(container).selectedDateText, 'Sat, 17 Oct');
      expect(repository.calls, hasLength(1));
    });

    test('goes back a day at a time and loads that day', () async {
      final yesterday = istDayStartUtc(2026, 10, 16);
      repository.days[yesterday] = dayOf([
        routeSession(
          's9',
          startedAt: DateTime.utc(2026, 10, 16, 3),
          endedAt: DateTime.utc(2026, 10, 16, 9),
          km: 4,
        ),
      ]);
      final container = open();
      await pumpEventQueue();

      notifierOf(container).previousDate();
      expect(stateOf(container).load, RouteLoad.loading);
      expect(stateOf(container).selectedDateText, 'Fri, 16 Oct');
      expect(
        stateOf(container).summary,
        isNull,
        reason: 'no leftovers from today',
      );
      await pumpEventQueue();

      expect(repository.calls.last.dayStartUtc, yesterday);
      expect(stateOf(container).summary!.distanceKm, 4);
      expect(stateOf(container).isToday, isFalse);

      notifierOf(container).nextDate();
      await pumpEventQueue();
      expect(stateOf(container).selectedDateText, 'Sat, 17 Oct');
      expect(stateOf(container).isToday, isTrue);
    });

    test(
      'a day older than 30 days is expired: totals only, no points read',
      () async {
        final container = open(
          RouteViewArgs(employeeId: 'e1', initialDate: DateTime(2026, 9, 10)),
        );
        final a = RouteViewArgs(
          employeeId: 'e1',
          initialDate: DateTime(2026, 9, 10),
        );
        repository.days[istDayStartUtc(2026, 9, 10)] = dayOf([
          routeSession(
            's1',
            startedAt: DateTime.utc(2026, 9, 10, 3),
            endedAt: DateTime.utc(2026, 9, 10, 9),
            km: 21.5,
          ),
        ]);
        container.listen(adminRouteViewControllerProvider(a), (_, _) {});
        await pumpEventQueue();

        final state = stateOf(container, a);
        expect(state.isExpired, isTrue);
        expect(repository.calls.last.withPoints, isFalse);
        expect(state.summary!.distanceKm, 21.5);
        expect(state.hasNoRoute, isFalse, reason: 'expired, not missing');
      },
    );

    test('exactly 30 days back still has its route; 31 does not', () async {
      final thirty = open(
        RouteViewArgs(employeeId: 'e1', initialDate: DateTime(2026, 9, 17)),
      );
      expect(
        stateOf(
          thirty,
          RouteViewArgs(employeeId: 'e1', initialDate: DateTime(2026, 9, 17)),
        ).isExpired,
        isFalse,
      );
      final thirtyOne = open(
        RouteViewArgs(employeeId: 'e1', initialDate: DateTime(2026, 9, 16)),
      );
      expect(
        stateOf(
          thirtyOne,
          RouteViewArgs(employeeId: 'e1', initialDate: DateTime(2026, 9, 16)),
        ).isExpired,
        isTrue,
      );
      await pumpEventQueue();
    });

    test('stepping back past the 30 days flips to expired', () async {
      final container = open(
        RouteViewArgs(employeeId: 'e1', initialDate: DateTime(2026, 9, 17)),
      );
      final a = RouteViewArgs(
        employeeId: 'e1',
        initialDate: DateTime(2026, 9, 17),
      );
      container.listen(adminRouteViewControllerProvider(a), (_, _) {});
      await pumpEventQueue();
      expect(stateOf(container, a).isExpired, isFalse);

      notifierOf(container, a).previousDate();
      await pumpEventQueue();

      expect(stateOf(container, a).isExpired, isTrue);
      expect(repository.calls.last.withPoints, isFalse);
    });

    test('the picker stops a year back', () async {
      final a = RouteViewArgs(
        employeeId: 'e1',
        initialDate: DateTime(2025, 10, 17),
      );
      final container = open(a);
      await pumpEventQueue();
      final calls = repository.calls.length;

      notifierOf(container, a).previousDate();
      await pumpEventQueue();

      expect(stateOf(container, a).selectedDateText, 'Fri, 17 Oct');
      expect(repository.calls.length, calls);
    });

    test('"today" comes from the server clock once a day has loaded', () async {
      // The phone thinks it is 17 Oct, the server says it is already 18 Oct IST.
      repository.serverNow = DateTime.utc(2026, 10, 17, 19);
      final container = open();
      await pumpEventQueue();

      expect(stateOf(container).isToday, isFalse);
    });
  });

  group('overtaken loads', () {
    test(
      'a slow answer for an old day never replaces the day on screen',
      () async {
        final yesterday = istDayStartUtc(2026, 10, 16);
        repository.gate(today);
        repository.days[today] = dayOf([routeSession('s-today', km: 99)]);
        repository.days[yesterday] = dayOf([
          routeSession(
            's-yesterday',
            startedAt: DateTime.utc(2026, 10, 16, 3),
            endedAt: DateTime.utc(2026, 10, 16, 9),
            km: 4,
          ),
        ]);
        final container = open();
        await pumpEventQueue();
        expect(
          stateOf(container).load,
          RouteLoad.loading,
          reason: 'today is slow',
        );

        notifierOf(container).previousDate();
        await pumpEventQueue();
        expect(stateOf(container).summary!.distanceKm, 4);

        repository.release(today);
        await pumpEventQueue();

        expect(stateOf(container).selectedDateText, 'Fri, 16 Oct');
        expect(
          stateOf(container).summary!.distanceKm,
          4,
          reason: 'still yesterday',
        );
      },
    );

    test(
      'a slow failure for an old day does not wipe the day on screen',
      () async {
        final yesterday = istDayStartUtc(2026, 10, 16);
        repository.gate(today);
        final container = open();
        await pumpEventQueue();
        repository.days[yesterday] = dayOf([
          routeSession(
            's1',
            startedAt: DateTime.utc(2026, 10, 16, 3),
            endedAt: DateTime.utc(2026, 10, 16, 9),
          ),
        ]);

        notifierOf(container).previousDate();
        await pumpEventQueue();
        repository.error = const NetworkException();
        repository.release(today);
        await pumpEventQueue();

        expect(stateOf(container).load, RouteLoad.loaded);
        expect(stateOf(container).errorMessage, isNull);
      },
    );
  });
}
