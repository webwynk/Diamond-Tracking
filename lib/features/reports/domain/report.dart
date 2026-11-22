import '../../duty/domain/duty_day.dart';
import '../../requests/domain/app_request.dart';

/// The longest range one report covers.
const int maxReportDays = 92;

/// A range of IST dates, both ends included (UTC midnight dates).
class ReportRange {
  ReportRange(this.from, this.to)
    : assert(!to.isBefore(from), 'to must not be before from');

  /// The month of [day], from the 1st to the last day.
  factory ReportRange.month(DateTime day) => ReportRange(
    DateTime.utc(day.year, day.month),
    DateTime.utc(day.year, day.month + 1, 0),
  );

  final DateTime from;
  final DateTime to;

  int get days => to.difference(from).inDays + 1;

  bool contains(DateTime day) => !day.isBefore(from) && !day.isAfter(to);

  @override
  bool operator ==(Object other) =>
      other is ReportRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// One person's record for one day, as the report shows it.
class ReportDay {
  const ReportDay({
    required this.dayId,
    required this.userId,
    required this.day,
    required this.status,
    this.leaveType,
    this.dutyOnAt,
    this.dutyOffAt,
    this.autoEnded = false,
    this.workedMinutes,
    this.distanceM,
    this.visits = 0,
  });

  factory ReportDay.fromRow(Map<String, dynamic> row, {int visits = 0}) {
    DateTime? time(Object? v) => v is String ? DateTime.parse(v).toUtc() : null;
    return ReportDay(
      dayId: (row['id'] as num).toInt(),
      userId: row['user_id'] as String,
      day: DateTime.parse('${row['day']}T00:00:00Z'),
      status: DayStatus.fromWire(row['status'] as String),
      leaveType: row['leave_type'] == null
          ? null
          : LeaveType.fromWire(row['leave_type'] as String),
      dutyOnAt: time(row['duty_on_at']),
      dutyOffAt: time(row['duty_off_at']),
      autoEnded: row['end_reason'] == 'auto',
      workedMinutes: (row['worked_minutes'] as num?)?.toInt(),
      distanceM: (row['distance_m'] as num?)?.toInt(),
      visits: visits,
    );
  }

  final int dayId;
  final String userId;
  final DateTime day;
  final DayStatus status;
  final LeaveType? leaveType;
  final DateTime? dutyOnAt;
  final DateTime? dutyOffAt;
  final bool autoEnded;
  final int? workedMinutes;
  final int? distanceM;
  final int visits;

  /// "Present", "Sick leave", "Waiting for admin".
  String get statusLabel =>
      status == DayStatus.leave ? (leaveType?.label ?? 'Leave') : status.label;

  ReportDay withVisits(int count) => ReportDay(
    dayId: dayId,
    userId: userId,
    day: day,
    status: status,
    leaveType: leaveType,
    dutyOnAt: dutyOnAt,
    dutyOffAt: dutyOffAt,
    autoEnded: autoEnded,
    workedMinutes: workedMinutes,
    distanceM: distanceM,
    visits: count,
  );
}

/// What the day list is narrowed to.
enum StatusFilter {
  all('All days'),
  present('Present'),
  halfDay('Half day'),
  absent('Absent'),
  leave('Leave'),
  waiting('Waiting');

  const StatusFilter(this.label);

  final String label;

  bool matches(ReportDay d) => switch (this) {
    StatusFilter.all => true,
    StatusFilter.present => d.status == DayStatus.present,
    StatusFilter.halfDay => d.status == DayStatus.halfDay,
    StatusFilter.absent => d.status == DayStatus.absent,
    StatusFilter.leave => d.status == DayStatus.leave,
    StatusFilter.waiting =>
      d.status == DayStatus.pending || d.status == DayStatus.onDuty,
  };
}

/// A person in the report, with their days in date order.
class PersonReport {
  PersonReport({
    required this.userId,
    required this.userCode,
    required this.name,
    required List<ReportDay> days,
    this.designation,
  }) : days = List<ReportDay>.unmodifiable(
         List<ReportDay>.of(days)
           ..sort((ReportDay a, ReportDay b) => a.day.compareTo(b.day)),
       );

  final String userId;
  final String userCode;
  final String name;
  final List<ReportDay> days;

  /// The job title, or null while none is set.
  final String? designation;

  int _count(bool Function(ReportDay d) test) => days.where(test).length;

  int get present => _count((ReportDay d) => d.status == DayStatus.present);
  int get halfDays => _count((ReportDay d) => d.status == DayStatus.halfDay);
  int get absent => _count((ReportDay d) => d.status == DayStatus.absent);
  int get sickLeave => _count(
    (ReportDay d) =>
        d.status == DayStatus.leave && d.leaveType == LeaveType.sick,
  );
  int get waiting => _count(StatusFilter.waiting.matches);

  /// Present counts 1, half day counts 0.5.
  double get attendance => present + halfDays / 2;

  int get workedMinutes =>
      days.fold(0, (int sum, ReportDay d) => sum + (d.workedMinutes ?? 0));
  int get distanceM =>
      days.fold(0, (int sum, ReportDay d) => sum + (d.distanceM ?? 0));
  int get visits => days.fold(0, (int sum, ReportDay d) => sum + d.visits);

  List<ReportDay> filtered(StatusFilter f) => days.where(f.matches).toList();
}

/// "12.5" or "12": attendance days without a needless ".0".
String formatDays(double d) =>
    d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(1);

/// Builds one report per person from their days. People with no days in the
/// range are left out unless [keepEmpty] (for example a new employee).
/// [designations] holds the job title of each person that has one, by id.
List<PersonReport> buildReports({
  required List<({String id, String code, String name})> people,
  required List<ReportDay> days,
  Map<String, String> designations = const <String, String>{},
  bool keepEmpty = false,
}) {
  final Map<String, List<ReportDay>> byUser = <String, List<ReportDay>>{};
  for (final ReportDay d in days) {
    byUser.putIfAbsent(d.userId, () => <ReportDay>[]).add(d);
  }
  return <PersonReport>[
    for (final ({String id, String code, String name}) p in people)
      if (keepEmpty || byUser.containsKey(p.id))
        PersonReport(
          userId: p.id,
          userCode: p.code,
          name: p.name,
          days: byUser[p.id] ?? const <ReportDay>[],
          designation: designations[p.id],
        ),
  ];
}
