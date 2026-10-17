import 'package:diamond_tracking/features/admin/places/presentation/controllers/admin_places_controller.dart';
import 'package:diamond_tracking/features/admin/places/presentation/controllers/admin_places_state.dart';

/// Test-only sample places. Production starts with none; tests that exercise
/// filtering, search and the form inject these.
const List<AdminPlaceItem> kFixturePlaces = [
  // 1. Shivpuri Farm
  AdminPlaceItem(
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
  AdminPlaceItem(
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
  AdminPlaceItem(
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
  AdminPlaceItem(
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
  AdminPlaceItem(
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

/// Seeds the places list with [kFixturePlaces].
class FixturePlacesNotifier extends AdminPlacesNotifier {
  @override
  AdminPlacesState build() => const AdminPlacesState(places: kFixturePlaces);
}

/// Provider override that seeds the places list for a test.
final fixturePlacesOverride = adminPlacesControllerProvider.overrideWith(
  FixturePlacesNotifier.new,
);
