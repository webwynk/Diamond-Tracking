import 'dart:io';

import 'package:diamond_tracking/core/time/ist.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/duty/domain/duty_failure.dart';
import 'package:diamond_tracking/features/duty/domain/duty_home.dart';
import 'package:diamond_tracking/features/requests/domain/app_request.dart';
import 'package:diamond_tracking/features/tracking/domain/tracking_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  DateTime ist(int h, [int m = 0]) => Ist.instantAt(2026, 11, 20, h, m);
  final DateTime today = DateTime.utc(2026, 11, 20);
  DutyDay day(DayStatus s) =>
      DutyDay(id: 1, day: today, status: s, dutyOnAt: ist(7));
  final TrackingSession session = TrackingSession(
    dayId: 1,
    pass: 'p',
    dutyOnAt: ist(7),
    autoOffAt: ist(23),
  );

  DutyPhase phase(DutyDay? d, DateTime at, {TrackingSession? s}) =>
      DutyHome(today: d, session: s, loadedAt: at).phaseAt(at);

  test('no duty yet: the window decides', () {
    expect(phase(null, ist(4, 59)), DutyPhase.beforeWindow);
    expect(phase(null, ist(5)), DutyPhase.canDutyOn);
    expect(phase(null, ist(8, 30)), DutyPhase.canDutyOn);
    expect(phase(null, ist(8, 31)), DutyPhase.windowClosed);
  });

  test('status from the server', () {
    expect(phase(day(DayStatus.onDuty), ist(12)), DutyPhase.onDuty);
    expect(phase(day(DayStatus.leave), ist(6)), DutyPhase.onLeave);
    expect(phase(day(DayStatus.pending), ist(18)), DutyPhase.ended);
    expect(phase(day(DayStatus.absent), ist(23, 30)), DutyPhase.ended);
  });

  test('duty off saved on the phone but not sent yet', () {
    final TrackingSession off = session.withDutyOff(ist(17), confirmed: false);
    expect(phase(day(DayStatus.onDuty), ist(17), s: off), DutyPhase.offSaved);
    expect(
      phase(
        day(DayStatus.onDuty),
        ist(17),
        s: session.withDutyOff(ist(17), confirmed: true),
      ),
      DutyPhase.ended,
    );
    expect(phase(day(DayStatus.pending), ist(17), s: off), DutyPhase.ended);
  });

  test('server errors become plain messages', () {
    expect(
      mapDutyError(const PostgrestException(message: 'duty_on_closed')),
      DutyFailure.closed,
    );
    expect(
      mapDutyError(const PostgrestException(message: 'on_leave_today')),
      DutyFailure.onLeave,
    );
    expect(
      mapDutyError(const PostgrestException(message: 'signed_in_elsewhere')),
      DutyFailure.signedInElsewhere,
    );
    expect(mapDutyError(const SocketException('x')), DutyFailure.noInternet);
    expect(mapDutyError(StateError('?')), DutyFailure.unknown);
  });

  test('the session file round-trips', () {
    final TrackingSession off = session.withDutyOff(ist(17), confirmed: true);
    final TrackingSession back = TrackingSession.fromJson(off.toJson());
    expect(back.offAt, ist(17));
    expect(back.offConfirmed, isTrue);
    expect(back.isActiveAt(ist(12)), isFalse);
    expect(session.isActiveAt(ist(22, 59)), isTrue);
    expect(session.isActiveAt(ist(23)), isFalse);
  });

  test('a leave day reads its leave type from the server', () {
    final DutyDay day = DutyDay.fromJson(<String, dynamic>{
      'id': 1,
      'day': '2026-11-20',
      'status': 'leave',
      'leave_type': 'sick',
      'distance_m': null,
    });
    expect(day.leaveType, LeaveType.sick);
    expect(
      DutyDay.fromJson(<String, dynamic>{
        'id': 2,
        'day': '2026-11-20',
        'status': 'present',
        'distance_m': 1200,
      }).distanceM,
      1200,
    );
  });
}
