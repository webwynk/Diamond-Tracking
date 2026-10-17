import 'package:flutter/foundation.dart';

/// Place category types for filtering and classification in Screen 24.
enum AdminPlaceCategory { all, farms, dealers, offices, warehouses, inactive }

/// Individual place / geofenced facility item in Screen 24.
class AdminPlaceItem {
  const AdminPlaceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.badgeTag,
    required this.radiusMeters,
    required this.location,
    required this.visitsThisMonth,
    required this.latitude,
    required this.longitude,
    this.isActive = true,
  });

  final String id;
  final String name;
  final AdminPlaceCategory category;
  final String badgeTag;
  final int radiusMeters;
  final String location;
  final int visitsThisMonth;
  final bool isActive;
  final double latitude;
  final double longitude;

  String get radiusAndLocation => '$radiusMeters m radius · $location';
  String get visitsText => '$visitsThisMonth visits this month';
}

/// Immutable state for Screen 24 Places List (Admin).
@immutable
class AdminPlacesState {
  const AdminPlacesState({
    required this.places,
    this.selectedCategory = AdminPlaceCategory.all,
    this.searchQuery = '',
  });

  final List<AdminPlaceItem> places;
  final AdminPlaceCategory selectedCategory;
  final String searchQuery;

  int get activePlacesCount => places.where((p) => p.isActive).length;

  List<AdminPlaceItem> get filteredPlaces {
    return places.where((place) {
      // 1. Category Filter
      final matchesCategory = switch (selectedCategory) {
        AdminPlaceCategory.all => true,
        AdminPlaceCategory.farms => place.category == AdminPlaceCategory.farms,
        AdminPlaceCategory.dealers =>
          place.category == AdminPlaceCategory.dealers,
        AdminPlaceCategory.offices =>
          place.category == AdminPlaceCategory.offices,
        AdminPlaceCategory.warehouses =>
          place.category == AdminPlaceCategory.warehouses,
        AdminPlaceCategory.inactive => !place.isActive,
      };

      if (!matchesCategory) return false;

      // 2. Search Query Filter
      if (searchQuery.trim().isEmpty) return true;
      final query = searchQuery.trim().toLowerCase();
      final nameMatches = place.name.toLowerCase().contains(query);
      final locationMatches = place.location.toLowerCase().contains(query);
      final tagMatches = place.badgeTag.toLowerCase().contains(query);
      final radiusMatches = '${place.radiusMeters}'.contains(query);

      return nameMatches || locationMatches || tagMatches || radiusMatches;
    }).toList();
  }

  AdminPlacesState copyWith({
    List<AdminPlaceItem>? places,
    AdminPlaceCategory? selectedCategory,
    String? searchQuery,
  }) {
    return AdminPlacesState(
      places: places ?? this.places,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
