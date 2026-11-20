import '../../routes/domain/geo_point.dart';

/// A dealer visit: the store, a note and a photo. A camera photo carries the
/// place it was taken; a gallery photo has none.
class Visit {
  const Visit({
    required this.id,
    required this.storeName,
    required this.fromGallery,
    required this.capturedAt,
    this.note,
    this.location,
    this.hasPhoto = true,
    this.photoRemoved = false,
  });

  factory Visit.fromRow(Map<String, dynamic> row) {
    final num? lat = row['lat_e6'] as num?;
    final num? lng = row['lng_e6'] as num?;
    return Visit(
      id: row['id'] as String,
      storeName: (row['store_name'] as String?) ?? 'Store',
      note: row['note'] as String?,
      fromGallery: row['from_gallery'] as bool,
      location: lat == null || lng == null
          ? null
          : GeoPoint(lat / 1e6, lng / 1e6),
      hasPhoto: row['photo_id'] != null,
      photoRemoved: row['photo_removed_at'] != null,
      capturedAt: DateTime.parse(row['captured_at'] as String).toUtc(),
    );
  }

  final String id;
  final String storeName;
  final String? note;
  final bool fromGallery;
  final GeoPoint? location;
  final bool hasPhoto;

  /// Photos are deleted after 90 days; the visit stays.
  final bool photoRemoved;
  final DateTime capturedAt;

  bool get showsPhoto => hasPhoto && !photoRemoved;
}

/// "22.57261, 88.36389".
String formatPoint(GeoPoint p) =>
    '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}';
