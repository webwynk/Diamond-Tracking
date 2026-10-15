import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_places_state.dart';

/// Riverpod 3 Notifier managing Screen 24 Places List.
class AdminPlacesNotifier extends Notifier<AdminPlacesState> {
  static final List<AdminPlaceItem> defaultPlaces = [
    // 1. Shivpuri Farm
    const AdminPlaceItem(
      id: 'place-1',
      name: 'Shivpuri Farm',
      category: AdminPlaceCategory.farms,
      badgeTag: 'BIO',
      radiusMeters: 500,
      location: 'Nashik, Maharashtra',
      visitsThisMonth: 14,
      isActive: true,
      latitude: 19.9975,
      longitude: 73.7898,
    ),

    // 2. Patel Agro Dealer
    const AdminPlaceItem(
      id: 'place-2',
      name: 'Patel Agro Dealer',
      category: AdminPlaceCategory.dealers,
      badgeTag: 'TIER 1',
      radiusMeters: 500,
      location: 'Sinnar, Maharashtra',
      visitsThisMonth: 9,
      isActive: true,
      latitude: 19.8456,
      longitude: 73.9982,
    ),

    // 3. Head Office
    const AdminPlaceItem(
      id: 'place-3',
      name: 'Head Office',
      category: AdminPlaceCategory.offices,
      badgeTag: 'HQ',
      radiusMeters: 200,
      location: 'Nashik, Maharashtra',
      visitsThisMonth: 41,
      isActive: true,
      latitude: 20.0112,
      longitude: 73.7905,
    ),

    // 4. Igatpuri Warehouse
    const AdminPlaceItem(
      id: 'place-4',
      name: 'Igatpuri Warehouse',
      category: AdminPlaceCategory.warehouses,
      badgeTag: 'STOCK',
      radiusMeters: 800,
      location: 'Igatpuri, Maharashtra',
      visitsThisMonth: 6,
      isActive: true,
      latitude: 19.6983,
      longitude: 73.5601,
    ),

    // 5. Old Deolali Farm (Inactive)
    const AdminPlaceItem(
      id: 'place-5',
      name: 'Old Deolali Farm',
      category: AdminPlaceCategory.farms,
      badgeTag: 'INACTIVE',
      radiusMeters: 500,
      location: 'Deolali, Maharashtra',
      visitsThisMonth: 0,
      isActive: false,
      latitude: 19.9450,
      longitude: 73.8320,
    ),
  ];

  @override
  AdminPlacesState build() {
    return AdminPlacesState(
      places: defaultPlaces,
      activePlacesCount: 38,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  void setCategory(AdminPlaceCategory category) {
    state = state.copyWith(selectedCategory: category);
  }

  void resetFilters() {
    state = state.copyWith(
      selectedCategory: AdminPlaceCategory.all,
      searchQuery: '',
    );
  }
}

/// Provider for Screen 24 Places List Notifier.
final adminPlacesControllerProvider =
    NotifierProvider<AdminPlacesNotifier, AdminPlacesState>(
  AdminPlacesNotifier.new,
);
