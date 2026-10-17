import 'package:flutter/foundation.dart';

/// One duty session as the admin sees it: a row of `public.duty_sessions`.
///
/// Shared by the route view and the attendance screen, so both add up the same
/// rows the same way (PRD F7/F8: their totals must reconcile).
@immutable
class AdminDutySession {
  const AdminDutySession({
    required this.id,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.distanceKm,
    this.visitsCount = 0,
    this.mockPointsCount = 0,
    this.employeeId,
  });

  final String id;

  /// `open`, `completed`, `auto_curfew` or `blocked`.
  final String status;
  final DateTime startedAt;

  /// Null while the session is still open.
  final DateTime? endedAt;

  /// The server's figure. For a finished session it is stored on the row; for
  /// an open one it comes from the server's running calculation. Null when the
  /// server could not give it (never guessed on the phone).
  final double? distanceKm;
  final int visitsCount;

  /// Points the phone flagged as mock locations, counted by the server.
  final int mockPointsCount;

  /// Whose session it is. Null where the read was already limited to one
  /// employee (the route view and the attendance screen); set for reports that
  /// read several employees at once.
  final String? employeeId;

  bool get isOpen => endedAt == null;
  bool get endedAutomatically => status == 'auto_curfew';
  bool get endedByBlock => status == 'blocked';

  /// How long the session lasted. An open one runs to [serverNow], the
  /// server's clock, never the phone's. Never negative.
  Duration durationAt(DateTime serverNow) {
    final length = (endedAt ?? serverNow).difference(startedAt);
    return length.isNegative ? Duration.zero : length;
  }

  /// Reads one `duty_sessions` row. Null when it cannot be a session.
  static AdminDutySession? tryParse(
    Map<String, dynamic> json, {
    double? runningDistanceKm,
  }) {
    final id = json['id'];
    final status = json['status'];
    final started = json['started_at'];
    if (id is! String || status is! String || started is! String) return null;
    final startedAt = DateTime.tryParse(started);
    if (startedAt == null) return null;
    final ended = json['ended_at'];
    final endedAt = ended is String ? DateTime.tryParse(ended) : null;
    final stored = json['total_distance_km'];
    final visits = json['visits_count'];
    final mocks = json['mock_points_count'];
    final employee = json['employee_id'];
    return AdminDutySession(
      id: id,
      status: status,
      startedAt: startedAt.toUtc(),
      endedAt: endedAt?.toUtc(),
      distanceKm: endedAt == null
          ? runningDistanceKm
          : (stored is num ? stored.toDouble() : double.tryParse('$stored')),
      visitsCount: visits is num ? visits.toInt() : 0,
      mockPointsCount: mocks is num ? mocks.toInt() : 0,
      employeeId: employee is String ? employee : null,
    );
  }
}
