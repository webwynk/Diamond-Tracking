import 'dart:async';

import 'package:diamond_tracking/core/utils/phone_clock.dart';
import 'package:diamond_tracking/domain/entities/admin_duty_session.dart';
import 'package:diamond_tracking/domain/repositories/attendance_repository.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/controllers/admin_attendance_controller.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'fake_route.dart';

/// 00:00 IST on the 1st of the IST month, as UTC.
DateTime istMonthStartUtc(int year, int month) =>
    DateTime.utc(year, month).subtract(const Duration(hours: 5, minutes: 30));

/// One call received by [FakeAttendanceRepository].
class AttendanceCall {
  const AttendanceCall(this.employeeId, this.monthStartUtc, this.monthEndUtc);

  final String employeeId;
  final DateTime monthStartUtc;
  final DateTime monthEndUtc;
}

/// Test-only [AttendanceRepository] that stands in for the server. It lives in
/// test/ so production code never contains a pretend backend.
///
/// [months] holds what each IST month returns (keyed by its UTC start); any
/// other month is empty. [gate] holds a month's answer back until released.
class FakeAttendanceRepository implements AttendanceRepository {
  FakeAttendanceRepository({this.employeeCreatedAt});

  final Map<DateTime, List<AdminDutySession>> months =
      <DateTime, List<AdminDutySession>>{};
  final Map<DateTime, Completer<void>> _gates = <DateTime, Completer<void>>{};

  /// Set to make every call fail the way the real repository does.
  Exception? error;

  final List<AttendanceCall> calls = <AttendanceCall>[];

  DateTime serverNow = kRouteNow;
  DateTime? employeeCreatedAt;
  bool truncated = false;

  void gate(DateTime monthStartUtc) =>
      _gates[monthStartUtc] = Completer<void>();

  void release(DateTime monthStartUtc) => _gates[monthStartUtc]?.complete();

  @override
  Future<AttendanceSource> fetchMonth({
    required String employeeId,
    required DateTime monthStartUtc,
    required DateTime monthEndUtc,
  }) async {
    calls.add(AttendanceCall(employeeId, monthStartUtc, monthEndUtc));
    final gate = _gates[monthStartUtc];
    if (gate != null) await gate.future;
    final failure = error;
    if (failure != null) throw failure;
    return AttendanceSource(
      sessions: months[monthStartUtc] ?? const <AdminDutySession>[],
      serverNow: serverNow,
      employeeCreatedAt: employeeCreatedAt,
      truncated: truncated,
    );
  }
}

/// A finished session on the given IST day, [startHour]:[startMinute] IST for
/// [minutes] minutes. [km] null means unknown.
AdminDutySession attendanceSession(
  String id, {
  required int year,
  required int month,
  required int day,
  int startHour = 8,
  int startMinute = 4,
  int minutes = 446,
  String status = 'completed',
  double? km = 12.345,
  int visits = 2,
  int flagged = 0,
  bool open = false,
  String? employeeId,
}) {
  final start = DateTime.utc(
    year,
    month,
    day,
    startHour,
    startMinute,
  ).subtract(const Duration(hours: 5, minutes: 30));
  return AdminDutySession(
    id: id,
    status: open ? 'open' : status,
    startedAt: start,
    endedAt: open ? null : start.add(Duration(minutes: minutes)),
    distanceKm: km,
    visitsCount: visits,
    mockPointsCount: flagged,
    employeeId: employeeId,
  );
}

/// Provider overrides that feed the attendance screen from [repository], with
/// the phone clock fixed at [kRouteNow] (Saturday 17 October 2026, 10:00 IST).
List<Override> attendanceOverrides(
  FakeAttendanceRepository repository, {
  DateTime? now,
}) {
  return <Override>[
    attendanceRepositoryProvider.overrideWithValue(repository),
    phoneClockProvider.overrideWithValue(() => now ?? kRouteNow),
  ];
}
