import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_skeletons.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../../shared/widgets/filter_sheet/controllers/filter_sheet_state.dart';
import '../../../../shared/widgets/filter_sheet/filter_bottom_sheet.dart';
import 'admin_employee_detail_page.dart';
import 'admin_employee_form_page.dart';
import 'controllers/admin_employee_list_controller.dart';
import 'controllers/admin_employee_list_state.dart';
import 'widgets/admin_employee_card.dart';
import 'widgets/admin_employee_search_filter_bar.dart';

/// Screen 17 — Employee List (Admin / Team).
///
/// Searchable, filterable, and paginated roster of all field staff:
/// - Pinned search and horizontal chip filtering (Active, On duty, Off duty, Blocked, Flags)
/// - Removable "Active only" modifier strip with "Clear all" action
/// - 80 dp responsive employee cards with monogram avatars, identity, and status pills
/// - 56 dp circular Floating Action Button for employee onboarding
class AdminEmployeeListPage extends ConsumerStatefulWidget {
  const AdminEmployeeListPage({
    super.key,
    this.onEmployeeSelected,
    this.onCreateEmployee,
  });

  final ValueChanged<AdminEmployeeItem>? onEmployeeSelected;
  final VoidCallback? onCreateEmployee;

  @override
  ConsumerState<AdminEmployeeListPage> createState() =>
      _AdminEmployeeListPageState();
}

class _AdminEmployeeListPageState extends ConsumerState<AdminEmployeeListPage> {
  @override
  void initState() {
    super.initState();
    // Providers must not be modified while the tree is building.
    Future<void>.microtask(
      () => ref
          .read(adminEmployeeListControllerProvider.notifier)
          .loadEmployees(),
    );
  }

  void _openCreateForm(BuildContext context) {
    final override = widget.onCreateEmployee;
    if (override != null) {
      override();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminEmployeeFormPage()),
    );
  }

  Future<void> _showFilterTuneModal(BuildContext context) async {
    final result = await FilterBottomSheet.show(context);
    if (result != null) {
      if (result.selectedStatuses.contains(EmployeeFilterStatus.onDuty)) {
        ref
            .read(adminEmployeeListControllerProvider.notifier)
            .setFilter(AdminEmployeeFilter.onDuty);
      } else if (result.selectedStatuses.contains(
        EmployeeFilterStatus.offDuty,
      )) {
        ref
            .read(adminEmployeeListControllerProvider.notifier)
            .setFilter(AdminEmployeeFilter.offDuty);
      } else if (result.selectedStatuses.contains(
        EmployeeFilterStatus.blocked,
      )) {
        ref
            .read(adminEmployeeListControllerProvider.notifier)
            .setFilter(AdminEmployeeFilter.blocked);
      } else if (result.selectedStatuses.contains(
        EmployeeFilterStatus.checkNeeded,
      )) {
        ref
            .read(adminEmployeeListControllerProvider.notifier)
            .setFilter(AdminEmployeeFilter.hasFlags);
      }
    }
  }

  /// What the Team tab shows while there is nothing to list: a skeleton while
  /// loading, an error with Retry when the load failed (never "no employees"),
  /// and the real empty state only after a successful load.
  Widget _buildEmptyBody(
    AdminEmployeeListState listState,
    AdminEmployeeListNotifier listNotifier,
  ) {
    final error = listState.errorMessage;
    if (error != null) {
      return AppErrorView(
        key: const Key('view-employee-list-error'),
        title: "Couldn't load the team",
        message: error,
        onRetry: () => listNotifier.loadEmployees(force: true),
      );
    }
    if (!listState.hasLoaded) {
      return const AppListSkeleton();
    }
    return Center(
      child: AppEmptyState.noEmployees(
        onAddEmployee: () => _openCreateForm(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(adminEmployeeListControllerProvider);
    final listNotifier = ref.read(adminEmployeeListControllerProvider.notifier);
    final filteredList = listState.filteredEmployees;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        style: AppTopBarStyle.brand,
        title: 'Team',
        actions: <Widget>[
          AppTopBarIconButton(
            key: const Key('btn-employee-filter-tune'),
            icon: Icons.tune_rounded,
            tooltip: 'Filter team',
            badgeCount: listState.filterTuneBadgeCount,
            badgeColor: AppColors.neutral0,
            badgeTextColor: AppColors.primary600,
            onPressed: () => _showFilterTuneModal(context),
          ),
        ],
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
            child: listState.employees.isEmpty
                ? _buildEmptyBody(listState, listNotifier)
                : filteredList.isEmpty
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
                : RefreshIndicator(
                    onRefresh: () => listNotifier.loadEmployees(force: true),
                    child: ListView.separated(
                      key: const Key('list-employee-roster'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x4,
                        AppSpacing.x1,
                        AppSpacing.x4,
                        88, // Clearance for the floating action button
                      ),
                      itemCount: filteredList.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final employee = filteredList[index];
                        return AdminEmployeeCard(
                          employee: employee,
                          onTap: () {
                            final onSelected = widget.onEmployeeSelected;
                            if (onSelected != null) {
                              onSelected(employee);
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AdminEmployeeDetailPage(
                                    employee: employee,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      // 3. Floating Action Button (56dp circular, #016893, white plus icon)
      floatingActionButton: FloatingActionButton(
        key: const Key('fab-add-employee'),
        onPressed: () => _openCreateForm(context),
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}
