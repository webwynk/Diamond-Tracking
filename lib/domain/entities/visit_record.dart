import 'package:flutter/foundation.dart';

/// Represents a field visit record captured by an employee on duty.
///
/// Adheres strictly to PRD F10 (as amended 2026-10-18) and the `public.visits` schema:
/// - Places and geofencing are removed; visits are captured manually by field staff.
/// - Store name is optional (max 80 chars).
/// - Observation note is optional (max 200 chars).
/// - In-situ photo is optional (camera only, uploaded to Cloudinary via signed handshake).
///   Skipping it needs no reason and sets no flag.
@immutable
class VisitRecord {
  const VisitRecord({
    required this.id,
    required this.sessionId,
    this.employeeId = '',
    this.storeName,
    this.note,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.capturedAt,
    this.createdAt,
    this.photoPublicId,
    this.photoAttachedAt,
    this.photoRemovedAt,
    this.localPhotoPath,
    this.synced = false,
  });

  /// Unique client-generated UUID for the visit.
  final String id;

  /// Foreign key referencing the active `duty_sessions.id`.
  final String sessionId;

  /// Foreign key referencing the employee profile (`profiles.id`).
  /// Populated by the server trigger `visits_before_insert()`.
  final String employeeId;

  /// Optional store or shop name (1 to 80 chars).
  final String? storeName;

  /// Optional observation note (1 to 200 chars).
  final String? note;

  /// GPS latitude at the instant of capture (-90 to 90).
  final double latitude;

  /// GPS longitude at the instant of capture (-180 to 180).
  final double longitude;

  /// GPS fix accuracy in meters (>= 0).
  final double? accuracy;

  /// Phone UTC timestamp when the visit was captured on-site.
  final DateTime capturedAt;

  /// Server UTC timestamp when the row was received.
  final DateTime? createdAt;

  /// Cloudinary public_id (`visit-<uuid>`). Set by the `visit-photos` Edge Function.
  final String? photoPublicId;

  /// Timestamp when the photo was verified and attached by the Edge Function.
  final DateTime? photoAttachedAt;

  /// Timestamp when the photo was purged (90-day retention).
  final DateTime? photoRemovedAt;

  /// Local on-device file path of the captured photo before/during upload.
  final String? localPhotoPath;

  /// Whether the visit record has synced to the Supabase backend.
  final bool synced;

  /// True if photo is attached remotely and has not been purged.
  bool get hasRemotePhoto => photoPublicId != null && photoRemovedAt == null;

  /// Creates a copy of this visit record with given fields updated.
  VisitRecord copyWith({
    String? id,
    String? sessionId,
    String? employeeId,
    String? storeName,
    String? note,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? capturedAt,
    DateTime? createdAt,
    String? photoPublicId,
    DateTime? photoAttachedAt,
    DateTime? photoRemovedAt,
    String? localPhotoPath,
    bool? synced,
  }) {
    return VisitRecord(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      employeeId: employeeId ?? this.employeeId,
      storeName: storeName ?? this.storeName,
      note: note ?? this.note,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      capturedAt: capturedAt ?? this.capturedAt,
      createdAt: createdAt ?? this.createdAt,
      photoPublicId: photoPublicId ?? this.photoPublicId,
      photoAttachedAt: photoAttachedAt ?? this.photoAttachedAt,
      photoRemovedAt: photoRemovedAt ?? this.photoRemovedAt,
      localPhotoPath: localPhotoPath ?? this.localPhotoPath,
      synced: synced ?? this.synced,
    );
  }

  /// Reads a row of `public.visits`.
  factory VisitRecord.fromMap(Map<String, dynamic> map) {
    return VisitRecord(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      employeeId: (map['employee_id'] as String?) ?? '',
      storeName: map['store_name'] as String?,
      note: map['note'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      capturedAt: DateTime.parse(map['captured_at'] as String),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      photoPublicId: map['photo_public_id'] as String?,
      photoAttachedAt: map['photo_attached_at'] != null
          ? DateTime.parse(map['photo_attached_at'] as String)
          : null,
      photoRemovedAt: map['photo_removed_at'] != null
          ? DateTime.parse(map['photo_removed_at'] as String)
          : null,
    );
  }

  /// Columns granted to `authenticated` role for INSERT into `public.visits`.
  /// `employee_id`, `created_at`, and photo columns are populated/managed by server triggers.
  Map<String, dynamic> toInsertPayload() {
    return {
      'id': id,
      'session_id': sessionId,
      if (storeName != null && storeName!.trim().isNotEmpty)
        'store_name': storeName!.trim(),
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      'captured_at': capturedAt.toUtc().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisitRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sessionId == other.sessionId &&
          storeName == other.storeName &&
          note == other.note &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          accuracy == other.accuracy &&
          capturedAt == other.capturedAt &&
          photoPublicId == other.photoPublicId &&
          localPhotoPath == other.localPhotoPath &&
          synced == other.synced;

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    storeName,
    note,
    latitude,
    longitude,
    accuracy,
    capturedAt,
    photoPublicId,
    localPhotoPath,
    synced,
  );
}
