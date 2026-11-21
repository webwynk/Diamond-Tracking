import 'geo_point.dart';

/// An employee's latest position, for the admin's live map.
class LivePosition {
  const LivePosition({
    required this.userId,
    required this.point,
    required this.recordedAt,
    this.dutyDayId,
    this.battery,
    this.mocked = false,
  });

  factory LivePosition.fromRow(Map<String, dynamic> row) => LivePosition(
    userId: row['user_id'] as String,
    dutyDayId: (row['duty_day_id'] as num?)?.toInt(),
    point: GeoPoint((row['lat_e6'] as num) / 1e6, (row['lng_e6'] as num) / 1e6),
    recordedAt: DateTime.parse(row['recorded_at'] as String).toUtc(),
    battery: (row['battery'] as num?)?.toInt(),
    mocked: row['mocked'] as bool? ?? false,
  );

  final String userId;
  final int? dutyDayId;
  final GeoPoint point;

  /// When the phone took this fix.
  final DateTime recordedAt;
  final int? battery;

  /// The latest point came from a fake-location app.
  final bool mocked;

  /// No fresh position for 5 minutes (no signal, or the phone stopped).
  bool isStaleAt(DateTime now) =>
      now.difference(recordedAt) > const Duration(minutes: 5);
}
