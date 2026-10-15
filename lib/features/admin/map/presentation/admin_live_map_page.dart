import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../dashboard/presentation/widgets/admin_bottom_navigation.dart';
import 'controllers/admin_live_map_controller.dart';
import 'controllers/admin_live_map_state.dart';
import 'widgets/admin_map_filter_chips_bar.dart';
import 'widgets/admin_map_floating_controls.dart';
import 'widgets/admin_map_search_bar.dart';
import 'widgets/admin_map_top_bar.dart';
import 'widgets/admin_map_vector_canvas.dart';
import 'widgets/live_map_employee_detail_sheet.dart';

/// Screen 15 — Admin Live Map (All Field Officers).
///
/// Provides enterprise administrators with full-density geospatial telemetry
/// of all 143 field officers across the Maharashtra agricultural basin.
class AdminLiveMapPage extends ConsumerStatefulWidget {
  const AdminLiveMapPage({
    super.key,
    this.onNavigateToHome,
    this.onNavigateToTeam,
    this.onNavigateToPlaces,
    this.onNavigateToReports,
    this.onNavigateToNotifications,
    this.onOfficerSelected,
  });

  final VoidCallback? onNavigateToHome;
  final VoidCallback? onNavigateToTeam;
  final VoidCallback? onNavigateToPlaces;
  final VoidCallback? onNavigateToReports;
  final VoidCallback? onNavigateToNotifications;
  final ValueChanged<MapOfficerItem>? onOfficerSelected;

  @override
  ConsumerState<AdminLiveMapPage> createState() => _AdminLiveMapPageState();
}

class _AdminLiveMapPageState extends ConsumerState<AdminLiveMapPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleFilterTune() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Officers',
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(modalCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),
                ListTile(
                  leading: const Icon(Icons.tune_rounded, color: AppColors.primary600),
                  title: const Text('All Districts & Talukas'),
                  subtitle: const Text('Showing 143 officers across 6 zones'),
                  trailing: const Icon(Icons.check_rounded, color: AppColors.primary600),
                  onTap: () {
                    Navigator.of(modalCtx).pop();
                    ref
                        .read(adminLiveMapControllerProvider.notifier)
                        .setFilter(AdminMapFilter.all);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.warning_rounded, color: AppColors.error),
                  title: const Text('Prioritize Critical & SOS'),
                  subtitle: const Text('Filter to 3 check-needed officers'),
                  onTap: () {
                    Navigator.of(modalCtx).pop();
                    ref
                        .read(adminLiveMapControllerProvider.notifier)
                        .setFilter(AdminMapFilter.needsCheck);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleOfficerTapped(MapOfficerItem officer) {
    ref.read(adminLiveMapControllerProvider.notifier).selectOfficer(officer);
    if (widget.onOfficerSelected != null) {
      widget.onOfficerSelected!(officer);
    }
  }

  void _handleClusterTapped(MapClusterItem cluster) {
    ref.read(adminLiveMapControllerProvider.notifier).selectCluster(cluster);
    AppSnackbar.show(
      context,
      message: '${cluster.title}: ${cluster.count} officers deployed in cluster.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(adminLiveMapControllerProvider);
    final mapNotifier = ref.read(adminLiveMapControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AdminMapTopBar(
        onSearchPressed: () {
          // Focus search field
        },
        onNotificationsPressed: widget.onNavigateToNotifications,
        onProfilePressed: () {
          AppSnackbar.show(context, message: 'Administrator profile options');
        },
      ),
      bottomNavigationBar: AdminBottomNavigationBar(
        currentIndex: 1, // Map is index 1
        onTap: (index) {
          if (index == 0) {
            if (widget.onNavigateToHome != null) {
              widget.onNavigateToHome!();
            } else {
              Navigator.of(context).maybePop();
            }
          } else if (index == 2) {
            widget.onNavigateToTeam?.call();
          } else if (index == 3) {
            widget.onNavigateToPlaces?.call();
          } else if (index == 4) {
            widget.onNavigateToReports?.call();
          }
        },
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // 1. Full-Bleed Regional Cartography Vector Map
            Positioned.fill(
              child: AdminMapVectorCanvas(
                officers: mapState.filteredOfficers,
                clusters: mapState.filteredClusters,
                selectedOfficerId: mapState.selectedOfficer?.id,
                isSatellite: mapState.isSatelliteLayer,
                onOfficerTapped: _handleOfficerTapped,
                onClusterTapped: _handleClusterTapped,
              ),
            ),

            // 2. Floating Top Overlay: Search Bar + Status Filter Chips
            Positioned(
              top: AppSpacing.x3,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                    child: AdminMapSearchBar(
                      controller: _searchController,
                      activeFilterCount: mapState.activeFilterBadgeCount,
                      onChanged: (val) => mapNotifier.setSearchQuery(val),
                      onClear: () {
                        _searchController.clear();
                        mapNotifier.setSearchQuery('');
                      },
                      onFilterPressed: _handleFilterTune,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  AdminMapFilterChipsBar(
                    selectedFilter: mapState.selectedFilter,
                    totalCount: mapState.totalOfficersCount,
                    onDutyCount: mapState.onDutyCount,
                    staleCount: mapState.staleCount,
                    needsCheckCount: mapState.needsCheckCount,
                    offDutyCount: mapState.offDutyCount,
                    blockedCount: mapState.blockedCount,
                    onFilterSelected: (filter) => mapNotifier.setFilter(filter),
                  ),
                ],
              ),
            ),

            // 3. Floating Bottom Controls: Live indicator + Map tools
            Positioned(
              left: 0,
              right: 0,
              bottom: mapState.selectedOfficer != null ? 116 : 0,
              child: AdminMapFloatingControls(
                isSatellite: mapState.isSatelliteLayer,
                onRecenter: () async {
                  await mapNotifier.recenterMap();
                  if (context.mounted) {
                    AppSnackbar.show(
                      context,
                      message: 'Map bounds re-centered to Nashik Basin.',
                    );
                  }
                },
                onToggleLayers: () {
                  mapNotifier.toggleLayer();
                  AppSnackbar.show(
                    context,
                    message: mapState.isSatelliteLayer
                        ? 'Switched to Street Cartography.'
                        : 'Switched to Satellite Imagery.',
                  );
                },
                onToggleListView: () {
                  if (widget.onNavigateToTeam != null) {
                    widget.onNavigateToTeam!();
                  } else {
                    AppSnackbar.show(
                      context,
                      message: 'Switching to team list view...',
                    );
                  }
                },
              ),
            ),

            // 4. Quick Officer Preview Bottom Card (when an officer is selected)
            if (mapState.selectedOfficer != null)
              Positioned(
                left: AppSpacing.x4,
                right: AppSpacing.x4,
                bottom: AppSpacing.x3,
                child: _buildOfficerPreviewCard(mapState.selectedOfficer!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficerPreviewCard(MapOfficerItem officer) {
    final isCritical = officer.isSos || officer.status == AdminOfficerStatus.needsCheck;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isCritical ? AppColors.error : AppColors.neutral200,
          width: isCritical ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isCritical ? AppColors.errorBg : AppColors.primary50,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isCritical ? Icons.warning_rounded : Icons.person_rounded,
                      color: isCritical ? AppColors.error : AppColors.primary600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        officer.name,
                        style: AppTypography.title.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${officer.employeeCode} · ${officer.locationName}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.neutral400,
                onPressed: () {
                  ref
                      .read(adminLiveMapControllerProvider.notifier)
                      .selectOfficer(null);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.battery_charging_full_rounded,
                    size: 16,
                    color: AppColors.neutral600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${officer.batteryPercent}%',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.neutral600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    officer.lastUpdated,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              TextButton(
                key: const Key('btn-view-officer-detail'),
                onPressed: () {
                  if (widget.onOfficerSelected != null) {
                    widget.onOfficerSelected!(officer);
                  } else {
                    LiveMapEmployeeDetailSheet.show(
                      context,
                      officer: officer,
                      onViewProfile: () {
                        Navigator.of(context).pop();
                        widget.onNavigateToTeam?.call();
                      },
                      onRouteView: () {
                        Navigator.of(context).pop();
                      },
                    );
                  }
                },
                child: Text(
                  'View Detail',
                  style: AppTypography.label.copyWith(
                    color: AppColors.primary600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
