import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../dashboard/presentation/widgets/admin_bottom_navigation.dart';
import 'controllers/admin_places_controller.dart';
import 'controllers/admin_places_state.dart';
import 'widgets/admin_place_card.dart';
import 'widgets/admin_places_filter_chips.dart';
import 'widgets/admin_places_search_bar.dart';
import 'widgets/admin_places_telemetry_banner.dart';
import 'widgets/admin_places_top_bar.dart';

/// Screen 24 — Places List (Admin).
///
/// Complete geofenced boundary registry and management console:
/// - 56 dp white app bar with "38 ACTIVE" pill badge and calibration/export tools
/// - Pinned 48 dp search field with instant filtering
/// - Horizontally scrolling category chips (All, Farms, Dealers, Offices, Warehouses, Inactive)
/// - RTK Synced geofence telemetry micro-banner (accuracy ±1.8m)
/// - Facility cards with 44x44 tinted icon badges, radius, taluka, and visits count
/// - Dynamic empty state when search/filter returns 0 matches
/// - Field agronomy perimeter helper banner
/// - 56 dp floating action button to create new geofences
/// - Persistent 5-item admin bottom navigation bar (Places tab active)
class AdminPlacesPage extends ConsumerStatefulWidget {
  const AdminPlacesPage({
    super.key,
    this.onBack,
    this.onCreatePlace,
    this.onPlaceSelected,
    this.onNavigateToHome,
    this.onNavigateToMap,
    this.onNavigateToTeam,
    this.onNavigateToReports,
  });

  final VoidCallback? onBack;
  final VoidCallback? onCreatePlace;
  final ValueChanged<AdminPlaceItem>? onPlaceSelected;
  final VoidCallback? onNavigateToHome;
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToTeam;
  final VoidCallback? onNavigateToReports;

  @override
  ConsumerState<AdminPlacesPage> createState() => _AdminPlacesPageState();
}

class _AdminPlacesPageState extends ConsumerState<AdminPlacesPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        widget.onNavigateToHome?.call();
        break;
      case 1:
        widget.onNavigateToMap?.call();
        break;
      case 2:
        widget.onNavigateToTeam?.call();
        break;
      case 3:
        // Already on Places
        break;
      case 4:
        widget.onNavigateToReports?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminPlacesControllerProvider);
    final notifier = ref.read(adminPlacesControllerProvider.notifier);
    final filteredPlaces = state.filteredPlaces;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AdminPlacesTopBar(
        activePlacesCount: state.activePlacesCount,
        onBack: widget.onBack,
        onTuneFilter: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Geofence satellite RTK calibration: ±1.8m nominal.'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        onExportCoordinates: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exporting 38 geofence perimeters (GeoJSON / CSV)...'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
      body: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.x3),

          // 1. Search Bar
          AdminPlacesSearchBar(
            controller: _searchController,
            onChanged: notifier.setSearchQuery,
            onClear: () {
              _searchController.clear();
              notifier.clearSearch();
            },
          ),
          const SizedBox(height: AppSpacing.x2 + 2),

          // 2. Category Filter Chips
          AdminPlacesFilterChips(
            selectedCategory: state.selectedCategory,
            onSelectCategory: notifier.setCategory,
          ),
          const SizedBox(height: AppSpacing.x2 + 2),

          // 3. Telemetry Sub-Banner
          const AdminPlacesTelemetryBanner(),
          const SizedBox(height: AppSpacing.x2),

          // 4. Places List Stream / Empty State
          Expanded(
            child: filteredPlaces.isEmpty
                ? _buildEmptyState(context, notifier)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x4,
                      AppSpacing.x1,
                      AppSpacing.x4,
                      80,
                    ),
                    children: <Widget>[
                      // Place Cards
                      ...filteredPlaces.map((place) {
                        return AdminPlaceCard(
                          place: place,
                          onTap: () {
                            if (widget.onPlaceSelected != null) {
                              widget.onPlaceSelected!(place);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Opening geofence perimeter for ${place.name}...',
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                        );
                      }),

                      const SizedBox(height: AppSpacing.x2),

                      // Field Agronomy Helper Banner
                      _buildAgronomyHelperBanner(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('btn-add-place'),
        onPressed: widget.onCreatePlace ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Launching GPS Boundary Pin Mapper...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
        backgroundColor: AppColors.primary600,
        foregroundColor: AppColors.neutral0,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: AdminBottomNavigationBar(
        currentIndex: 3, // Places tab active
        onTap: _handleNavigation,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AdminPlacesNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.search_off_rounded,
                color: AppColors.info,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            Text(
              'No matching geofences',
              style: AppTypography.title.copyWith(
                color: AppColors.neutral900,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              'Try modifying search terms or resetting category filters to display rural polygon anchors.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.neutral500,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            ElevatedButton(
              key: const Key('btn-reset-places-filter'),
              onPressed: () {
                _searchController.clear();
                notifier.resetFilters();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary600,
                foregroundColor: AppColors.neutral0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                elevation: 0,
              ),
              child: const Text('Reset Filter Criteria'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgronomyHelperBanner() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral200, width: 1),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary600,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Need a custom perimeter?',
                  style: AppTypography.label.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Walk the field boundary with RTK handheld mode turned ON, or tap the action button to drop GPS pins.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
