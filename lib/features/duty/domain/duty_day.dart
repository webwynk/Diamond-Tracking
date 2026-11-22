import '../../requests/domain/app_request.dart' show LeaveType;

/// A day's attendance status, as the database stores it.
enum DayStatus {
  onDuty('on_duty'),
  present('present'),
  halfDay('half_day'),
  absent('absent'),
  leave('leave'),

  /// A short day waiting for the admin's decision.
  pending('pending');

  const DayStatus(this.wire);

  final String wire;

  static DayStatus fromWire(String value) =>
      DayStatus.values.firstWhere((DayStatus s) => s.wire == value);

  String get label => switch (this) {
    DayStatus.onDuty => 'On duty',
    DayStatus.present => 'Present',
    DayStatus.halfDay => 'Half day',
    DayStatus.absent => 'Absent',
    DayStatus.leave => 'On leave',
    DayStatus.pending => 'Waiting for admin',
  };
}

/// One employee's record for one day.
class DutyDay {
  const DutyDay({
    required this.id,
    required this.day,
    required this.status,
    this.dutyOnAt,
    this.dutyOffAt,
    this.autoEnded = false,
    this.workedMinutes,
    this.distanceM,
    this.leaveType,
    this.userId,
  });

  factory DutyDay.fromJson(Map<String, dynamic> json) => DutyDay(
    id: (json['id'] as num).toInt(),
    day: DateTime.parse('${json['day']}T00:00:00Z'),
    status: DayStatus.fromWire(json['status'] as String),
    dutyOnAt: _time(json['duty_on_at']),
    dutyOffAt: _time(json['duty_off_at']),
    autoEnded: json['end_reason'] == 'auto',
    workedMinutes: (json['worked_minutes'] as num?)?.toInt(),
    distanceM: (json['distance_m'] as num?)?.toInt(),
    leaveType: json['leave_type'] is String
        ? LeaveType.fromWire(json['leave_type'] as String)
        : null,
    userId: json['user_id'] as String?,
  );

  final int id;

  /// The IST date, as a UTC midnight date.
  final DateTime day;
  final DayStatus status;
  final DateTime? dutyOnAt;
  final DateTime? dutyOffAt;

  /// Ended by the 11:00 PM automatic duty off.
  final bool autoEnded;
  final int? workedMinutes;
  final int? distanceM;

  /// Sick, on a leave day (the only kind of leave).
  final LeaveType? leaveType;

  /// Set when the row was read with its user (admin lists).
  final String? userId;

  static DateTime? _time(Object? value) =>
      value is String ? DateTime.parse(value).toUtc() : null;
}

/// What duty on (or resume) returns: the day and its upload pass.
class DutyStart {
  const DutyStart({required this.day, required this.pass});

  factory DutyStart.fromJson(Map<String, dynamic> json) => DutyStart(
    day: DutyDay.fromJson(json['day'] as Map<String, dynamic>),
    pass: json['upload_pass'] as String,
  );

  final DutyDay day;
  final String pass;
}
