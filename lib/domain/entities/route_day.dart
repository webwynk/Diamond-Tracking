import 'package:flutter/foundation.dart';

import 'admin_duty_session.dart';

/// One stored GPS point of a duty session, as the route view needs it.
@immutable
class RoutePoint {
  const RoutePoint({
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracy,
    this.isMock = false,
  });

  final String sessionId;
  final double latitude;
  final double longitude;

  /// Metres, as reported by the phone.
  final double? accuracy;

  /// The phone flagged this point as a mock (fake) location.
  final bool isMock;

  /// When the phone recorded the point (UTC).
  final DateTime recordedAt;

  /// Reads one `location_points` row. Answers null for a row that cannot be a
  /// point, so one bad row never breaks a whole day.
  static RoutePoint? tryParse(Map<String, dynamic> json) {
    final session = json['session_id'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final recorded = json['recorded_at'];
    if (session is! String ||
        latitude is! num ||
        longitude is! num ||
        recorded is! String) {
      return null;
    }
    final at = DateTime.tryParse(recorded);
    if (at == null) return null;
    final accuracy = json['accuracy'];
    return RoutePoint(
      sessionId: session,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      accuracy: accuracy is num ? accuracy.toDouble() : null,
      isMock: json['is_mock'] == true,
      recordedAt: at.toUtc(),
    );
  }
}

/// Everything stored for one employee on one day.
@immutable
class RouteDay {
  const RouteDay({
    required this.sessions,
    required this.points,
    required this.serverNow,
    this.truncated = false,
  });

  /// Sessions that started on the day, oldest first.
  final List<AdminDutySession> sessions;

  /// Their points, in time order.
  final List<RoutePoint> points;

  /// The server's clock when this was read (UTC).
  final DateTime serverNow;

  /// More points exist than the safety cap allows to be read.
  final bool truncated;
}
