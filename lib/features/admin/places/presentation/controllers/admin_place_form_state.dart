import 'package:flutter/foundation.dart';

/// Form place types for Screen 25 Create / Edit Place.
enum PlaceFormType {
  farm,
  dealer,
  office,
  warehouse,
  other,
}

/// Immutable state for Screen 25 Create / Edit Place (Admin).
@immutable
class AdminPlaceFormState {
  const AdminPlaceFormState({
    this.placeId,
    this.name = 'Shivpuri Farm',
    this.type = PlaceFormType.farm,
    this.radiusMeters = 500.0,
    this.latitude = 19.99753,
    this.longitude = 73.78981,
    this.isActive = true,
    this.adjacentPlaceName = 'Patel Agro Dealer',
    this.adjacentDistanceMeters = 320,
    this.isSaving = false,
    this.isSatellite = false,
    this.errorMessage,
  });

  final String? placeId;
  final String name;
  final PlaceFormType type;
  final double radiusMeters;
  final double latitude;
  final double longitude;
  final bool isActive;
  final String adjacentPlaceName;
  final int adjacentDistanceMeters;
  final bool isSaving;
  final bool isSatellite;
  final String? errorMessage;

  bool get isEditMode => placeId != null;
  String get coordinatesText =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  String get radiusDisplay => '${radiusMeters.round()} m';

  AdminPlaceFormState copyWith({
    String? placeId,
    String? name,
    PlaceFormType? type,
    double? radiusMeters,
    double? latitude,
    double? longitude,
    bool? isActive,
    String? adjacentPlaceName,
    int? adjacentDistanceMeters,
    bool? isSaving,
    bool? isSatellite,
    String? errorMessage,
  }) {
    return AdminPlaceFormState(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      type: type ?? this.type,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isActive: isActive ?? this.isActive,
      adjacentPlaceName: adjacentPlaceName ?? this.adjacentPlaceName,
      adjacentDistanceMeters:
          adjacentDistanceMeters ?? this.adjacentDistanceMeters,
      isSaving: isSaving ?? this.isSaving,
      isSatellite: isSatellite ?? this.isSatellite,
      errorMessage: errorMessage,
    );
  }
}
