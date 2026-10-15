import 'package:flutter/foundation.dart';

import '../../core/utils/duty_time_helper.dart';

/// Status of a duty session matching the server schema.
enum DutySessionStatus {
  open,
  completed,
  autoCurfew,
  blocked,
}

/// Represents an employee's duty shift record.
///
/// Adheres strictly to PRD F3, F4 and business rules BR-1 through BR-8.
@immutable
class DutySession {
  const DutySession({
    required this.id,
    required this.employeeId,
    required this.startedAt,
    this.status = DutySessionStatus.open,
    this.endedAt,
    this.totalDistanceKm = 0.0,
    this.visitsCount = 0,
    this.mockPointsCount = 0,
    this.endReason,
    this.notes,
  });

  /// Unique session UUID.
  final String id;

  /// Foreign key referencing profiles.id of the employee.
  final String employeeId;

  /// Current lifecycle state.
  final DutySessionStatus status;

  /// UTC timestamp when duty was started.
  final DateTime startedAt;

  /// UTC timestamp when duty was ended (null while session is open).
  final DateTime? endedAt;

  /// Total calculated distance in kilometers (reconciled server-side per BR-8).
  final double totalDistanceKm;

  /// Total verified agricultural visits conducted during this session.
  final int visitsCount;

  /// Counter of telemetry points flagged with mock GPS provider (BR-9).
  final int mockPointsCount;

  /// Optional reason string (e.g. "normal", "auto_curfew", "blocked").
  final String? endReason;

  /// Optional administrative or employee note.
  final String? notes;

  /// Whether the session is currently active and accepting GPS points.
  bool get isOpen => status == DutySessionStatus.open && endedAt == null;

  /// Computes elapsed duration.
  Duration get elapsedDuration {
    final end = endedAt ?? DateTime.now().toUtc();
    return end.difference(startedAt);
  }

  /// Formatted duration string (e.g. "8h 12m" or "0h 0m").
  String get formattedElapsed => DutyTimeHelper.formatElapsed(elapsedDuration);

  /// Formatted distance string (e.g. "47.3 km").
  String get formattedDistanceKm =>
      '${DutyTimeHelper.formatDistanceKm(totalDistanceKm)} km';

  DutySession copyWith({
    String? id,
    String? employeeId,
    DutySessionStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    double? totalDistanceKm,
    int? visitsCount,
    int? mockPointsCount,
    String? endReason,
    String? notes,
  }) {
    return DutySession(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      visitsCount: visitsCount ?? this.visitsCount,
      mockPointsCount: mockPointsCount ?? this.mockPointsCount,
      endReason: endReason ?? this.endReason,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'status': status.name,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'total_distance_km': totalDistanceKm,
      'visits_count': visitsCount,
      'mock_points_count': mockPointsCount,
      'end_reason': endReason,
      'notes': notes,
    };
  }

  factory DutySession.fromJson(Map<String, dynamic> json) {
    return DutySession(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      status: DutySessionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DutySessionStatus.open,
      ),
      startedAt: DateTime.parse(json['started_at'] as String).toUtc(),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String).toUtc()
          : null,
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0.0,
      visitsCount: json['visits_count'] as int? ?? 0,
      mockPointsCount: json['mock_points_count'] as int? ?? 0,
      endReason: json['end_reason'] as String?,
      notes: json['notes'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DutySession &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          employeeId == other.employeeId &&
          status == other.status &&
          startedAt == other.startedAt &&
          endedAt == other.endedAt &&
          totalDistanceKm == other.totalDistanceKm &&
          visitsCount == other.visitsCount;

  @override
  int get hashCode =>
      id.hashCode ^
      employeeId.hashCode ^
      status.hashCode ^
      startedAt.hashCode ^
      endedAt.hashCode ^
      totalDistanceKm.hashCode ^
      visitsCount.hashCode;
}
