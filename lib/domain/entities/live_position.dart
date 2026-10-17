import 'package:flutter/foundation.dart';

/// How an on-duty employee's last position reads on the live map.
///
/// The order is the order of severity: a cluster takes the colour of the worst
/// status inside it (docs/07 section 3). Off duty and blocked have no position
/// row, so they never appear on the map.
enum LiveStatus { active, stale, suspect }

/// The latest known position of one employee who is on duty: one row of
/// `public.live_locations`, which the database keeps current and removes when
/// duty ends.
@immutable
class LivePosition {
  const LivePosition({
    required this.employeeId,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracy,
    this.batteryLevel,
    this.isMock = false,
  });

  /// A point older than this is "stale" (PRD section 3 status table).
  static const Duration staleAfter = Duration(minutes: 5);

  final String employeeId;
  final String sessionId;
  final double latitude;
  final double longitude;

  /// Metres, as reported by the phone.
  final double? accuracy;

  /// Percent, 0 to 100, when the phone reported it.
  final int? batteryLevel;

  /// The phone flagged this point as a mock (fake) location.
  final bool isMock;

  /// When the phone recorded the point (UTC).
  final DateTime recordedAt;

  /// Reads one `live_locations` row. Answers null for a row that cannot be a
  /// position (missing or wrongly typed fields), so one bad row never breaks
  /// the whole map.
  static LivePosition? tryParse(Map<String, dynamic> json) {
    final employeeId = json['employee_id'];
    final sessionId = json['session_id'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final recordedAt = json['recorded_at'];
    if (employeeId is! String ||
        sessionId is! String ||
        latitude is! num ||
        longitude is! num ||
        recordedAt is! String) {
      return null;
    }
    final recorded = DateTime.tryParse(recordedAt);
    if (recorded == null) return null;
    final accuracy = json['accuracy'];
    final battery = json['battery_level'];
    return LivePosition(
      employeeId: employeeId,
      sessionId: sessionId,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      accuracy: accuracy is num ? accuracy.toDouble() : null,
      batteryLevel: battery is num ? battery.toInt() : null,
      isMock: json['is_mock'] == true,
      recordedAt: recorded.toUtc(),
    );
  }

  /// The status at [now] (use the server-corrected time, never a raw phone
  /// clock): a mock-flagged point is suspect, then age decides.
  LiveStatus statusAt(DateTime now) {
    if (isMock) return LiveStatus.suspect;
    if (now.difference(recordedAt) > staleAfter) return LiveStatus.stale;
    return LiveStatus.active;
  }
}
