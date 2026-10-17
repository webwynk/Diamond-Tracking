import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_places_state.dart';

/// Riverpod 3 Notifier managing Screen 24 Places List.
class AdminPlacesNotifier extends Notifier<AdminPlacesState> {
  @override
  AdminPlacesState build() {
    return const AdminPlacesState(places: <AdminPlaceItem>[]);
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
