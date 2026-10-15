import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../dashboard/presentation/widgets/admin_bottom_navigation.dart';
import 'controllers/admin_employee_list_controller.dart';
import 'controllers/admin_employee_list_state.dart';
import 'widgets/admin_employee_card.dart';
import 'widgets/admin_employee_search_filter_bar.dart';
import 'widgets/admin_employee_top_bar.dart';

/// Screen 17 — Employee List (Admin / Team).
///
/// Searchable, filterable, and paginated roster of all 143 agricultural field staff:
/// - Pinned search and horizontal chip filtering (Active, On duty, Off duty, Blocked, Flags)
/// - Removable "Active only" modifier strip with "Clear all" action
/// - 80 dp responsive employee cards with monogram avatars, identity, and status pills
/// - 56 dp circular Floating Action Button for employee onboarding
/// - Persistent Admin Bottom Navigation Bar with "Team" active
class AdminEmployeeListPage extends ConsumerWidget {
  const AdminEmployeeListPage({
    super.key,
    this.onEmployeeSelected,
    this.onCreateEmployee,
    this.onNavigateToHome,
    this.onNavigateToMap,
    this.onNavigateToPlaces,
    this.onNavigateToReports,
  });

  final ValueChanged<AdminEmployeeItem>? onEmployeeSelected;
  final VoidCallback? onCreateEmployee;
  final VoidCallback? onNavigateToHome;
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToPlaces;
  final VoidCallback? onNavigateToReports;

  void _showFilterTuneModal(BuildContext context, WidgetRef ref) {
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
                      'Filter Roster',
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
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
                  leading: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.primary600,
                  ),
                  title: const Text('Active Staff Only'),
                  subtitle: const Text('Exclude blocked and suspended employees'),
                  onTap: () {
                    Navigator.of(modalCtx).pop();
                    ref
                        .read(adminEmployeeListControllerProvider.notifier)
                        .setFilter(AdminEmployeeFilter.active);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                  ),
                  title: const Text('Flagged & Suspect Staff'),
                  subtitle: const Text('Show 3 officers with audit anomalies'),
                  onTap: () {
                    Navigator.of(modalCtx).pop();
                    ref
                        .read(adminEmployeeListControllerProvider.notifier)
                        .setFilter(AdminEmployeeFilter.hasFlags);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(adminEmployeeListControllerProvider);
    final listNotifier = ref.read(adminEmployeeListControllerProvider.notifier);
    final filteredList = listState.filteredEmployees;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AdminEmployeeTopBar(
        badgeCount: listState.filterTuneBadgeCount,
        onFilterTunePressed: () => _showFilterTuneModal(context, ref),
      ),
      body: Column(
        children: [
          // 1. Pinned Search, Filter Chips, and Active Filter Strip
          AdminEmployeeSearchFilterBar(
            selectedFilter: listState.selectedFilter,
            searchQuery: listState.searchQuery,
            filterActiveOnly: listState.filterActiveOnly,
            filteredCount: filteredList.length,
            totalCount: listState.totalEmployeesCount,
            activeCount: listState.activeEmployeesCount,
            onDutyCount: listState.onDutyCount,
            offDutyCount: listState.offDutyCount,
            blockedCount: listState.blockedCount,
            hasFlagsCount: listState.hasFlagsCount,
            onFilterSelected: listNotifier.setFilter,
            onSearchChanged: listNotifier.setSearchQuery,
            onClearSearch: listNotifier.clearSearch,
            onRemoveActiveOnly: listNotifier.removeActiveOnlyFilter,
            onClearAll: listNotifier.clearAllFilters,
          ),

          // 2. Scrollable Roster List
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.x6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.person_search_rounded,
                            size: 48,
                            color: AppColors.textDisabled,
                          ),
                          const SizedBox(height: AppSpacing.x3),
                          Text(
                            'No field officers match your search.',
                            style: AppTypography.title.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.x1),
                          Text(
                            'Try adjusting your search terms or filter criteria.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    key: const Key('list-employee-roster'),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x4,
                      AppSpacing.x1,
                      AppSpacing.x4,
                      88, // Clearance for FAB and bottom navigation
                    ),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final employee = filteredList[index];
                      return AdminEmployeeCard(
                        employee: employee,
                        onTap: () {
                          if (onEmployeeSelected != null) {
                            onEmployeeSelected!(employee);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Selected ${employee.name}.'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      // 3. Floating Action Button (56dp circular, #016893, white plus icon)
      floatingActionButton: FloatingActionButton(
        key: const Key('fab-add-employee'),
        onPressed: onCreateEmployee ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening employee onboarding form...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      // 4. Admin Bottom Navigation Bar with "Team" active (Index 2)
      bottomNavigationBar: AdminBottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              onNavigateToHome?.call();
              break;
            case 1:
              onNavigateToMap?.call();
              break;
            case 2:
              // Already on Team
              break;
            case 3:
              onNavigateToPlaces?.call();
              break;
            case 4:
              onNavigateToReports?.call();
              break;
          }
        },
      ),
    );
  }
}
