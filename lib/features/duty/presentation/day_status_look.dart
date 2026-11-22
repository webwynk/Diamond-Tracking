import '../../../core/design/ds_status.dart';
import '../domain/duty_day.dart';

/// The colours of a day's status (design v2): Present green, Half day sky,
/// Sick leave rose, Absent red, Waiting amber, On duty blue.
DsStatus dayStatusTone(DutyDay d) => switch (d.status) {
  DayStatus.onDuty => DsStatus.onDuty,
  DayStatus.present => DsStatus.present,
  DayStatus.halfDay => DsStatus.halfDay,
  DayStatus.absent => DsStatus.absent,
  DayStatus.pending => DsStatus.waiting,
  DayStatus.leave => DsStatus.sick,
};

/// The words for a day's status: "On duty now", "Sick leave", "Present".
String dayStatusText(DutyDay d) => switch (d.status) {
  DayStatus.onDuty => 'On duty now',
  DayStatus.leave => d.leaveType?.label ?? 'On leave',
  _ => d.status.label,
};
