import 'package:flutter/foundation.dart';

/// What happened, for the admin's Recent activity feed.
enum AdminActivityKind {
  dutyStarted,
  dutyEnded,

  /// The server ended it at 23:00 IST; shown as "Duty ended automatically".
  dutyAutoEnded,
  employeeCreated,
  employeeBlocked,
  employeeUnblocked,
}

/// One event in the Recent activity feed: a duty change or an admin action.
@immutable
class AdminActivityEvent {
  const AdminActivityEvent({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.personName,
    this.employeeCode,
    this.detail,
  });

  /// Unique across kinds, for example `start:<session id>`.
  final String id;
  final AdminActivityKind kind;
  final DateTime occurredAt;

  /// The employee the event is about.
  final String personName;
  final String? employeeCode;

  /// Extra words, for example "Blocked by Admin Name".
  final String? detail;
}
