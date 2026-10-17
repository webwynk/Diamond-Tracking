import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/app_empty_state.dart';
import '../../../../../shared/widgets/app_error_view.dart';
import '../../../../../shared/widgets/app_skeletons.dart';
import '../../../employees/presentation/controllers/admin_employee_list_controller.dart';
import '../../../employees/presentation/controllers/admin_employee_list_state.dart';
import '../controllers/admin_reports_state.dart';

/// Picks whose report an employee summary is about, from the roster.
class AdminReportsEmployeeSheet extends ConsumerStatefulWidget {
  const AdminReportsEmployeeSheet({super.key, this.selectedId});

  /// The employee already chosen, marked in the list.
  final String? selectedId;

  static Future<ReportEmployeeChoice?> show(
    BuildContext context, {
    String? selectedId,
  }) {
    return showModalBottomSheet<ReportEmployeeChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlTop),
      builder: (_) => AdminReportsEmployeeSheet(selectedId: selectedId),
    );
  }

  @override
  ConsumerState<AdminReportsEmployeeSheet> createState() =>
      _AdminReportsEmployeeSheetState();
}

class _AdminReportsEmployeeSheetState
    extends ConsumerState<AdminReportsEmployeeSheet> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    // The roster is normally loaded by the Team tab; load it here if not.
    Future.microtask(
      () => ref
          .read(adminEmployeeListControllerProvider.notifier)
          .loadEmployees(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(adminEmployeeListControllerProvider);
    final needle = _query.trim().toLowerCase();
    final employees = [
      for (final e in roster.employees)
        if (needle.isEmpty ||
            e.name.toLowerCase().contains(needle) ||
            e.employeeCode.toLowerCase().contains(needle))
          e,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x4,
                  AppSpacing.x2,
                  AppSpacing.x2,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Choose an employee',
                        style: AppTypography.title.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  0,
                  AppSpacing.x4,
                  AppSpacing.x2,
                ),
                child: TextField(
                  key: const Key('field-report-employee-search'),
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search by name or code',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                  ),
                ),
              ),
              Flexible(child: _body(roster, employees)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(
    AdminEmployeeListState roster,
    List<AdminEmployeeItem> employees,
  ) {
    if (roster.isLoading && !roster.hasLoaded) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.x4),
        child: AppListSkeleton(itemCount: 5),
      );
    }
    if (!roster.hasLoaded && roster.errorMessage != null) {
      return AppErrorView(
        title: "Couldn't load the team",
        message: roster.errorMessage!,
        onRetry: () => ref
            .read(adminEmployeeListControllerProvider.notifier)
            .loadEmployees(force: true),
      );
    }
    if (employees.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: _query.trim().isEmpty
            ? AppEmptyState.noEmployees()
            : AppEmptyState.searchNotFound(query: _query.trim()),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: employees.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.neutral200),
      itemBuilder: (context, index) {
        final e = employees[index];
        final selected = e.id == widget.selectedId;
        return ListTile(
          key: Key('report-employee-row-${e.id}'),
          selected: selected,
          selectedTileColor: AppColors.primary50,
          onTap: () => Navigator.of(context).pop(
            ReportEmployeeChoice(id: e.id, name: e.name, code: e.employeeCode),
          ),
          title: Text(
            e.name,
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            [
              e.employeeCode,
              if (!e.isActive) 'Blocked',
            ].where((part) => part.isNotEmpty).join(' · '),
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          trailing: selected
              ? const Icon(Icons.check_rounded, color: AppColors.primary600)
              : null,
        );
      },
    );
  }
}
