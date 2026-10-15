import 'package:flutter/foundation.dart';

/// Represents a field visit record captured by an employee.
///
/// Adheres strictly to PRD F10, F9, and business rule BR-12.
@immutable
class VisitRecord {
  const VisitRecord({
    required this.id,
    required this.dutySessionId,
    required this.employeeId,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.placeId,
    this.accuracy,
    this.distanceMeters,
    this.photoPath,
    this.photoSkipped = false,
    this.photoSkipReason,
    this.notes,
    this.synced = false,
  });

  /// Unique UUID for the visit.
  final String id;

  /// Foreign key referencing the active duty_session.
  final String dutySessionId;

  /// Foreign key referencing the employee profile.
  final String employeeId;

  /// Display name of the visit location (e.g. "Shivpuri Farm", or custom name).
  final String placeName;

  /// Registered place UUID if triggered within a geofence.
  final String? placeId;

  /// Latitude coordinate at the instant of capture.
  final double latitude;

  /// Longitude coordinate at the instant of capture.
  final double longitude;

  /// GPS fix accuracy in meters.
  final double? accuracy;

  /// Distance in meters from registered place center if in a geofence.
  final double? distanceMeters;

  /// Local file path or remote Cloudinary public_id/URL.
  final String? photoPath;

  /// Whether photo capture was skipped per BR-12.
  final bool photoSkipped;

  /// Mandatory reason if photo was skipped.
  final String? photoSkipReason;

  /// Optional observation notes (max 200 chars).
  final String? notes;

  /// UTC timestamp of capture.
  final DateTime capturedAt;

  /// Whether the visit has synced to the remote server.
  final bool synced;

  /// Creates a copy of this visit record with given fields updated.
  VisitRecord copyWith({
    String? id,
    String? dutySessionId,
    String? employeeId,
    String? placeName,
    String? placeId,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? distanceMeters,
    String? photoPath,
    bool? photoSkipped,
    String? photoSkipReason,
    String? notes,
    DateTime? capturedAt,
    bool? synced,
  }) {
    return VisitRecord(
      id: id ?? this.id,
      dutySessionId: dutySessionId ?? this.dutySessionId,
      employeeId: employeeId ?? this.employeeId,
      placeName: placeName ?? this.placeName,
      placeId: placeId ?? this.placeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      photoPath: photoPath ?? this.photoPath,
      photoSkipped: photoSkipped ?? this.photoSkipped,
      photoSkipReason: photoSkipReason ?? this.photoSkipReason,
      notes: notes ?? this.notes,
      capturedAt: capturedAt ?? this.capturedAt,
      synced: synced ?? this.synced,
    );
  }

  /// Deserializes a database or cache map to a [VisitRecord].
  factory VisitRecord.fromMap(Map<String, dynamic> map) {
    return VisitRecord(
      id: map['id'] as String,
      dutySessionId: map['duty_session_id'] as String,
      employeeId: map['employee_id'] as String,
      placeName: map['place_name'] as String? ?? 'Field Location',
      placeId: map['place_id'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      distanceMeters: (map['distance_meters'] as num?)?.toDouble(),
      photoPath: map['photo_path'] as String?,
      photoSkipped: map['photo_skipped'] as bool? ?? false,
      photoSkipReason: map['photo_skip_reason'] as String?,
      notes: map['notes'] as String?,
      capturedAt: DateTime.parse(map['captured_at'] as String),
      synced: map['synced'] as bool? ?? false,
    );
  }

  /// Serializes this [VisitRecord] to a database map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'duty_session_id': dutySessionId,
      'employee_id': employeeId,
      'place_name': placeName,
      'place_id': placeId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'distance_meters': distanceMeters,
      'photo_path': photoPath,
      'photo_skipped': photoSkipped,
      'photo_skip_reason': photoSkipReason,
      'notes': notes,
      'captured_at': capturedAt.toIso8601String(),
      'synced': synced,
    };
  }
}
