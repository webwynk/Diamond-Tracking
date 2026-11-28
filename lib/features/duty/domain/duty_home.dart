import '../../../core/rules/duty_rules.dart';
import '../../../core/time/ist.dart';
import '../../tracking/domain/tracking_session.dart';
import 'duty_day.dart';

/// What the home screen shows.
enum DutyPhase {
  /// Before 5:00 AM, nothing recorded yet.
  beforeWindow,

  /// 5:00 to 8:30 AM: the duty on button.
  canDutyOn,

  /// Outside 5:00 to 8:30 AM, but the admin allowed duty on today.
  allowedByAdmin,

  /// After 8:30 AM with no duty: duty on is closed for today.
  windowClosed,

  onDuty,

  /// Duty off was pressed without internet; the phone sends it later.
  offSaved,

  /// The day is finished (present, waiting for admin, half day, absent).
  ended,

  onLeave,
}

/// Everything the home screen needs, from the server and the phone.
class DutyHome {
  const DutyHome({
    required this.today,
    required this.session,
    required this.loadedAt,
    this.serverReachable = true,
    this.trackingProblem,
    this.dutyOnAllowed = false,
  });

  /// Today's record from the server (or rebuilt from the phone when offline).
  final DutyDay? today;

  /// The tracker's session on this phone, if it is for today.
  final TrackingSession? session;

  /// The trusted time when this was loaded.
  final DateTime loadedAt;

  /// False when today's record could not be fetched (no internet).
  final bool serverReachable;

  /// Set when duty is on but route recording could not be started.
  final String? trackingProblem;

  /// The admin allowed duty on today outside the window.
  final bool dutyOnAllowed;

  DutyPhase phaseAt(DateTime now) {
    final DutyDay? day = today;
    final TrackingSession? s = session;
    if (day != null && s != null && s.dayId == day.id && s.isOff) {
      return day.status == DayStatus.onDuty && !s.offConfirmed
          ? DutyPhase.offSaved
          : DutyPhase.ended;
    }
    if (day == null) {
      if (DutyRules.canDutyOn(now)) return DutyPhase.canDutyOn;
      if (dutyOnAllowed && DutyRules.canUsePermitAt(now)) {
        return DutyPhase.allowedByAdmin;
      }
      return Ist.minuteOfDay(now) < DutyRules.dutyOnStartMinute
          ? DutyPhase.beforeWindow
          : DutyPhase.windowClosed;
    }
    return switch (day.status) {
      DayStatus.onDuty => DutyPhase.onDuty,
      DayStatus.leave => DutyPhase.onLeave,
      _ => DutyPhase.ended,
    };
  }
}

/// What happened at duty off, for the message after it.
class DutyOffOutcome {
  const DutyOffOutcome({required this.savedOffline, this.status});

  /// No internet: the duty off is saved and sent later.
  final bool savedOffline;

  /// The day's status from the server, when it was reached.
  final DayStatus? status;
}
