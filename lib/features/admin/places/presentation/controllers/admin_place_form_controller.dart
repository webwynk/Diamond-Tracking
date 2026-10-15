import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_place_form_state.dart';
import 'admin_places_state.dart';

/// Riverpod 3 Notifier managing Screen 25 Create / Edit Place form.
class AdminPlaceFormNotifier extends Notifier<AdminPlaceFormState> {
  @override
  AdminPlaceFormState build() {
    return const AdminPlaceFormState();
  }

  void initializeForPlace(AdminPlaceItem? place) {
    if (place == null) {
      state = const AdminPlaceFormState();
      return;
    }

    final formType = switch (place.category) {
      AdminPlaceCategory.farms => PlaceFormType.farm,
      AdminPlaceCategory.dealers => PlaceFormType.dealer,
      AdminPlaceCategory.offices => PlaceFormType.office,
      AdminPlaceCategory.warehouses => PlaceFormType.warehouse,
      _ => PlaceFormType.other,
    };

    state = AdminPlaceFormState(
      placeId: place.id,
      name: place.name,
      type: formType,
      radiusMeters: place.radiusMeters.toDouble(),
      latitude: place.latitude,
      longitude: place.longitude,
      isActive: place.isActive,
    );
  }

  void setName(String name) {
    state = state.copyWith(name: name, errorMessage: null);
  }

  void setType(PlaceFormType type) {
    state = state.copyWith(type: type);
  }

  void setRadius(double radiusMeters) {
    final clamped = radiusMeters.clamp(50.0, 2000.0);
    state = state.copyWith(radiusMeters: clamped);
  }

  void setIsActive(bool isActive) {
    state = state.copyWith(isActive: isActive);
  }

  void toggleSatellite() {
    state = state.copyWith(isSatellite: !state.isSatellite);
  }

  bool validateAndSave() {
    if (state.name.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Place name cannot be empty');
      return false;
    }
    state = state.copyWith(isSaving: true, errorMessage: null);
    return true;
  }
}

/// Provider for Screen 25 Create / Edit Place Form Notifier.
final adminPlaceFormControllerProvider =
    NotifierProvider<AdminPlaceFormNotifier, AdminPlaceFormState>(
  AdminPlaceFormNotifier.new,
);
