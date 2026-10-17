import 'package:flutter/foundation.dart';

/// Represents a field visit record captured by an employee on duty.
///
/// Adheres strictly to PRD F10 (as amended 2026-10-18) and the `public.visits` schema:
/// - Places and geofencing are removed; visits are captured manually by field staff.
/// - Store name is optional (max 80 chars).
/// - Observation note is optional (max 200 chars).
/// - In-situ photo is optional (camera only, uploaded to Cloudinary via signed handshake).
@immutable
class VisitRecord {
  const VisitRecord({
    required this.id,
    String? sessionId,
    String? dutySessionId,
    this.employeeId = '',
    String? storeName,
    String? placeName,
    String? note,
    String? notes,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.capturedAt,
    this.createdAt,
    this.photoPublicId,
    this.photoAttachedAt,
    this.photoRemovedAt,
    String? localPhotoPath,
    String? photoPath,
    this.synced = false,
    // Backwards-compatible legacy parameters
    String? placeId,
    double? distanceMeters,
    bool photoSkipped = false,
    String? photoSkipReason,
  })  : sessionId = sessionId ?? dutySessionId ?? '',
        storeName = storeName ?? placeName,
        note = note ?? notes,
        localPhotoPath = localPhotoPath ?? photoPath,
        _legacyDutySessionId = dutySessionId,
        _legacyPlaceName = placeName,
        _legacyNotes = notes,
        _legacyPhotoPath = photoPath,
        _legacyPlaceId = placeId,
        _legacyDistanceMeters = distanceMeters,
        _legacyPhotoSkipped = photoSkipped,
        _legacyPhotoSkipReason = photoSkipReason;

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

  // Legacy fields for backward compatibility with existing tests and widgets
  final String? _legacyDutySessionId;
  final String? _legacyPlaceName;
  final String? _legacyNotes;
  final String? _legacyPhotoPath;
  final String? _legacyPlaceId;
  final double? _legacyDistanceMeters;
  final bool _legacyPhotoSkipped;
  final String? _legacyPhotoSkipReason;

  /// Backwards compatible session ID getter.
  String get dutySessionId =>
      sessionId.isNotEmpty ? sessionId : (_legacyDutySessionId ?? '');

  /// Backwards compatible place name getter.
  String get placeName {
    final currentStore = storeName;
    if (currentStore != null && currentStore.trim().isNotEmpty) {
      return currentStore.trim();
    }
    final legacyPlace = _legacyPlaceName;
    if (legacyPlace != null && legacyPlace.trim().isNotEmpty) {
      return legacyPlace.trim();
    }
    return 'Field location';
  }

  /// Backwards compatible note getter.
  String? get notes => note ?? _legacyNotes;

  /// Backwards compatible photo path getter.
  String? get photoPath => localPhotoPath ?? _legacyPhotoPath ?? photoPublicId;

  /// Backwards compatible photo skipped flag.
  bool get photoSkipped =>
      _legacyPhotoSkipped || (photoPublicId == null && localPhotoPath == null);

  /// Backwards compatible photo skip reason getter.
  String? get photoSkipReason => _legacyPhotoSkipReason;

  /// Backwards compatible geofence distance getter.
  double? get distanceMeters => _legacyDistanceMeters;

  /// Backwards compatible placeId getter.
  String? get placeId => _legacyPlaceId;

  /// True if photo is attached remotely and has not been purged.
  bool get hasRemotePhoto => photoPublicId != null && photoRemovedAt == null;

  /// True if photo exists either locally or remotely.
  bool get hasPhoto => localPhotoPath != null || hasRemotePhoto;

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
    // Legacy support
    String? dutySessionId,
    String? placeName,
    String? notes,
    String? photoPath,
    bool? photoSkipped,
    String? photoSkipReason,
    double? distanceMeters,
    String? placeId,
  }) {
    return VisitRecord(
      id: id ?? this.id,
      sessionId: sessionId ?? dutySessionId ?? this.sessionId,
      employeeId: employeeId ?? this.employeeId,
      storeName: storeName ?? placeName ?? this.storeName,
      note: note ?? notes ?? this.note,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      capturedAt: capturedAt ?? this.capturedAt,
      createdAt: createdAt ?? this.createdAt,
      photoPublicId: photoPublicId ?? this.photoPublicId,
      photoAttachedAt: photoAttachedAt ?? this.photoAttachedAt,
      photoRemovedAt: photoRemovedAt ?? this.photoRemovedAt,
      localPhotoPath: localPhotoPath ?? photoPath ?? this.localPhotoPath,
      synced: synced ?? this.synced,
      placeId: placeId ?? _legacyPlaceId,
      distanceMeters: distanceMeters ?? _legacyDistanceMeters,
      photoSkipped: photoSkipped ?? _legacyPhotoSkipped,
      photoSkipReason: photoSkipReason ?? _legacyPhotoSkipReason,
    );
  }

  /// Deserializes a database or cache map to a [VisitRecord].
  factory VisitRecord.fromMap(Map<String, dynamic> map) {
    return VisitRecord(
      id: map['id'] as String,
      sessionId:
          (map['session_id'] ?? map['duty_session_id'] ?? '') as String,
      employeeId: (map['employee_id'] as String?) ?? '',
      storeName: (map['store_name'] ?? map['place_name']) as String?,
      note: (map['note'] ?? map['notes']) as String?,
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
      localPhotoPath:
          (map['local_photo_path'] ?? map['photo_path']) as String?,
      synced: map['synced'] as bool? ?? false,
      placeId: map['place_id'] as String?,
      distanceMeters: (map['distance_meters'] as num?)?.toDouble(),
      photoSkipped: map['photo_skipped'] as bool? ?? false,
      photoSkipReason: map['photo_skip_reason'] as String?,
    );
  }

  /// Serializes this [VisitRecord] to a map for local caching.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'employee_id': employeeId,
      'store_name': storeName,
      'note': note,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'captured_at': capturedAt.toUtc().toIso8601String(),
      'created_at': createdAt?.toUtc().toIso8601String(),
      'photo_public_id': photoPublicId,
      'photo_attached_at': photoAttachedAt?.toUtc().toIso8601String(),
      'photo_removed_at': photoRemovedAt?.toUtc().toIso8601String(),
      'local_photo_path': localPhotoPath,
      'synced': synced,
      // Legacy keys for backward compatibility
      'duty_session_id': sessionId,
      'place_name': placeName,
      'place_id': _legacyPlaceId,
      'notes': note,
      'photo_path': localPhotoPath ?? photoPublicId,
      'photo_skipped': photoSkipped,
      'photo_skip_reason': photoSkipReason,
      'distance_meters': _legacyDistanceMeters,
    };
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
