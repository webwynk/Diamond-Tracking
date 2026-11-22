import '../../duty/domain/duty_day.dart';

enum RequestKind {
  attendance('attendance', 'Attendance'),
  leave('leave', 'Leave'),
  shortDuty('short_duty', 'Short duty');

  const RequestKind(this.wire, this.label);

  final String wire;
  final String label;

  static RequestKind fromWire(String v) =>
      values.firstWhere((RequestKind k) => k.wire == v);
}

enum RequestStatus {
  pending('pending', 'Waiting'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  cancelled('cancelled', 'Cancelled');

  const RequestStatus(this.wire, this.label);

  final String wire;
  final String label;

  static RequestStatus fromWire(String v) =>
      values.firstWhere((RequestStatus s) => s.wire == v);
}

/// Sick leave is the only kind (owner, 2026-11-23: casual leave removed).
/// The database refuses any other (requests_sick_leave_only and
/// duty_days_sick_leave_only).
enum LeaveType {
  sick('sick', 'Sick leave');

  const LeaveType(this.wire, this.label);

  final String wire;
  final String label;

  static LeaveType fromWire(String v) =>
      values.firstWhere((LeaveType t) => t.wire == v);
}

/// An attendance request, a leave request or a short duty to review.
class AppRequest {
  const AppRequest({
    required this.id,
    required this.userId,
    required this.kind,
    required this.status,
    required this.createdAt,
    this.day,
    this.dutyOnAt,
    this.dutyOffAt,
    this.leaveType,
    this.dates = const <DateTime>[],
    this.message,
    this.hasPhoto = false,
    this.extraPhotos = 0,
    this.photoRemoved = false,
    this.decision,
    this.decisionNote,
    this.decidedAt,
  });

  factory AppRequest.fromRow(Map<String, dynamic> row) => AppRequest(
    id: (row['id'] as num).toInt(),
    userId: row['user_id'] as String,
    kind: RequestKind.fromWire(row['kind'] as String),
    status: RequestStatus.fromWire(row['status'] as String),
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    day: _date(row['day']),
    dutyOnAt: _time(row['duty_on_at']),
    dutyOffAt: _time(row['duty_off_at']),
    leaveType: row['leave_type'] == null
        ? null
        : LeaveType.fromWire(row['leave_type'] as String),
    dates: <DateTime>[
      for (final Object? d in (row['dates'] as List<dynamic>?) ?? <Object?>[])
        _date(d)!,
    ],
    message: row['message'] as String?,
    hasPhoto: row['photo_id'] != null,
    extraPhotos: (row['extra_photo_ids'] as List<dynamic>?)?.length ?? 0,
    photoRemoved: row['photo_removed_at'] != null,
    decision: row['decision'] == null
        ? null
        : DayStatus.fromWire(row['decision'] as String),
    decisionNote: row['decision_note'] as String?,
    decidedAt: _time(row['decided_at']),
  );

  final int id;
  final String userId;
  final RequestKind kind;
  final RequestStatus status;
  final DateTime createdAt;

  /// attendance and short duty: the IST date (UTC midnight).
  final DateTime? day;
  final DateTime? dutyOnAt;
  final DateTime? dutyOffAt;
  final LeaveType? leaveType;

  /// leave: the IST dates, sorted.
  final List<DateTime> dates;
  final String? message;
  final bool hasPhoto;

  /// Photos after the first (up to 2 more).
  final int extraPhotos;

  /// How many photos the request has.
  int get photoCount => hasPhoto ? 1 + extraPhotos : 0;

  /// Photos are deleted after 90 days; the request stays (L69).
  final bool photoRemoved;
  final DayStatus? decision;
  final String? decisionNote;
  final DateTime? decidedAt;

  bool get isPending => status == RequestStatus.pending;

  /// The decisions an admin can make, in button order.
  List<DayStatus> get choices => switch (kind) {
    RequestKind.attendance => const <DayStatus>[
      DayStatus.present,
      DayStatus.halfDay,
      DayStatus.absent,
    ],
    RequestKind.leave => const <DayStatus>[DayStatus.leave, DayStatus.absent],
    RequestKind.shortDuty => const <DayStatus>[
      DayStatus.present,
      DayStatus.halfDay,
      DayStatus.absent,
    ],
  };

  /// Only employees' own attendance and leave requests can be cancelled.
  bool get cancellable => isPending && kind != RequestKind.shortDuty;

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.parse('${v}T00:00:00Z') : null;

  static DateTime? _time(Object? v) =>
      v is String ? DateTime.parse(v).toUtc() : null;
}

/// The admin's button text for a decision on [kind].
String decisionLabel(RequestKind kind, DayStatus d) => switch ((kind, d)) {
  (RequestKind.leave, DayStatus.leave) => 'Approve',
  (RequestKind.leave, DayStatus.absent) => 'Reject',
  (RequestKind.attendance, DayStatus.absent) => 'Reject',
  (_, DayStatus.present) => 'Present',
  (_, DayStatus.halfDay) => 'Half day',
  (_, DayStatus.absent) => 'Absent',
  _ => d.label,
};
