import 'dart:async';

import 'package:diamond_tracking/core/utils/phone_clock.dart';
import 'package:diamond_tracking/domain/entities/admin_duty_session.dart';
import 'package:diamond_tracking/domain/entities/route_day.dart';
import 'package:diamond_tracking/domain/repositories/route_repository.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/controllers/admin_route_view_controller.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// The phone clock used by route tests: Saturday 17 October 2026, 10:00 IST.
final DateTime kRouteNow = DateTime.utc(2026, 10, 17, 4, 30);

/// 00:00 IST of the IST calendar day [year]-[month]-[day], as UTC.
DateTime istDayStartUtc(int year, int month, int day) => DateTime.utc(
  year,
  month,
  day,
).subtract(const Duration(hours: 5, minutes: 30));

/// One call received by [FakeRouteRepository].
class RouteCall {
  const RouteCall(
    this.employeeId,
    this.dayStartUtc,
    this.dayEndUtc,
    this.withPoints,
  );

  final String employeeId;
  final DateTime dayStartUtc;
  final DateTime dayEndUtc;
  final bool withPoints;
}

/// Test-only [RouteRepository] that stands in for the server. It lives in
/// test/ so production code never contains a pretend backend.
///
/// [days] holds what each IST day returns (keyed by its UTC start); any other
/// day is empty. [gate] holds a day's answer back until the test releases it.
class FakeRouteRepository implements RouteRepository {
  FakeRouteRepository();

  final Map<DateTime, RouteDay> days = <DateTime, RouteDay>{};
  final Map<DateTime, Completer<void>> _gates = <DateTime, Completer<void>>{};

  /// Set to make every call fail the way the real repository does.
  Exception? error;

  final List<RouteCall> calls = <RouteCall>[];

  /// The server clock returned for days that have no entry.
  DateTime serverNow = kRouteNow;

  /// Holds back the answer for [dayStartUtc] until [release] is called.
  void gate(DateTime dayStartUtc) => _gates[dayStartUtc] = Completer<void>();

  void release(DateTime dayStartUtc) => _gates[dayStartUtc]?.complete();

  @override
  Future<RouteDay> fetchDay({
    required String employeeId,
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    bool withPoints = true,
  }) async {
    calls.add(RouteCall(employeeId, dayStartUtc, dayEndUtc, withPoints));
    final gate = _gates[dayStartUtc];
    if (gate != null) await gate.future;
    final failure = error;
    if (failure != null) throw failure;
    final day = days[dayStartUtc];
    if (day == null) {
      return RouteDay(
        sessions: const <AdminDutySession>[],
        points: const <RoutePoint>[],
        serverNow: serverNow,
      );
    }
    return withPoints
        ? day
        : RouteDay(
            sessions: day.sessions,
            points: const <RoutePoint>[],
            serverNow: day.serverNow,
          );
  }
}

/// A duty session for tests. Times are UTC.
AdminDutySession routeSession(
  String id, {
  String status = 'completed',
  DateTime? startedAt,
  DateTime? endedAt,
  double? km = 12.345,
  int visits = 2,
  bool open = false,
}) {
  return AdminDutySession(
    id: id,
    status: open ? 'open' : status,
    // 08:04 IST.
    startedAt: startedAt ?? DateTime.utc(2026, 10, 17, 2, 34),
    // 15:30 IST.
    endedAt: open ? null : (endedAt ?? DateTime.utc(2026, 10, 17, 10)),
    distanceKm: km,
    visitsCount: visits,
  );
}

/// A stored point for tests, [seconds] after 08:04 IST on 17 October.
RoutePoint routePoint(
  double latitude,
  double longitude,
  int seconds, {
  String session = 's1',
  double? accuracy = 5,
  bool isMock = false,
}) {
  return RoutePoint(
    sessionId: session,
    latitude: latitude,
    longitude: longitude,
    recordedAt: DateTime.utc(
      2026,
      10,
      17,
      2,
      34,
    ).add(Duration(seconds: seconds)),
    accuracy: accuracy,
    isMock: isMock,
  );
}

/// A simple walk of [count] good points, 10 s apart.
List<RoutePoint> routeWalk({int count = 5, String session = 's1'}) => [
  for (var i = 0; i < count; i++)
    routePoint(20 + i * 0.0001, 73, i * 10, session: session),
];

/// Provider overrides that feed the route view from [repository], with the
/// phone clock fixed at [kRouteNow].
List<Override> routeOverrides(FakeRouteRepository repository, {DateTime? now}) {
  return <Override>[
    routeRepositoryProvider.overrideWithValue(repository),
    phoneClockProvider.overrideWithValue(() => now ?? kRouteNow),
  ];
}
