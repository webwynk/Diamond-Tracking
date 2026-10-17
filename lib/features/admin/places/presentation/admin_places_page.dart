import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import 'admin_place_form_page.dart';
import 'controllers/admin_places_controller.dart';
import 'controllers/admin_places_state.dart';
import 'widgets/admin_place_card.dart';
import 'widgets/admin_places_filter_chips.dart';
import 'widgets/admin_places_search_bar.dart';

/// Screen 24 — Places List (Admin).
///
/// Complete geofenced boundary registry and management console:
/// - Shared top app bar (brand) with "38 ACTIVE" pill badge and calibration/export tools
/// - Pinned 48 dp search field with instant filtering
/// - Horizontally scrolling category chips (All, Farms, Dealers, Offices, Warehouses, Inactive)
/// - RTK Synced geofence telemetry micro-banner (accuracy ±1.8m)
/// - Facility cards with 44x44 tinted icon badges, radius, taluka, and visits count
/// - Dynamic empty state when search/filter returns 0 matches
/// - Field agronomy perimeter helper banner
/// - 56 dp floating action button to create new geofences
class AdminPlacesPage extends ConsumerStatefulWidget {
  const AdminPlacesPage({super.key, this.onCreatePlace, this.onPlaceSelected});

  final VoidCallback? onCreatePlace;
  final ValueChanged<AdminPlaceItem>? onPlaceSelected;

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

  void _openCreateForm(BuildContext context) {
    final override = widget.onCreatePlace;
    if (override != null) {
      override();
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AdminPlaceFormPage()));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminPlacesControllerProvider);
    final notifier = ref.read(adminPlacesControllerProvider.notifier);
    final filteredPlaces = state.filteredPlaces;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        style: AppTopBarStyle.brand,
        title: 'Places',
        titleTrailing: AppBadge(
          label: '${state.activePlacesCount} ACTIVE',
          backgroundColor: AppColors.primary50,
          textColor: AppColors.primary700,
        ),
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

          // 3. Places List Stream / Empty State
          Expanded(
            child: state.places.isEmpty
                ? Center(
                    child: AppEmptyState(
                      icon: Icons.domain_outlined,
                      title: 'No places yet',
                      description:
                          'Add your first farm, dealer, office or warehouse.',
                      actionLabel: 'Add place',
                      onActionPressed: () => _openCreateForm(context),
                      isActionOutlined: false,
                    ),
                  )
                : filteredPlaces.isEmpty
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
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) =>
                                      AdminPlaceFormPage(place: place),
                                ),
                              );
                            }
                          },
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('btn-add-place'),
        onPressed: () => _openCreateForm(context),
        backgroundColor: AppColors.primary600,
        foregroundColor: AppColors.neutral0,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
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
              style: AppTypography.body.copyWith(color: AppColors.neutral500),
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
}
