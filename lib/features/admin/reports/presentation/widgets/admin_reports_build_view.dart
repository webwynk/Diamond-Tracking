import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_reports_state.dart';

/// Panel A: Report Builder Configuration View for Screen 26.
class AdminReportsBuildView extends StatelessWidget {
  const AdminReportsBuildView({
    super.key,
    required this.state,
    required this.onSelectReportType,
    required this.onSelectDatePreset,
    required this.onRemoveEmployee,
    required this.onSelectFormat,
    required this.onGenerateReport,
  });

  final AdminReportsState state;
  final ValueChanged<ReportType> onSelectReportType;
  final ValueChanged<DateRangePreset> onSelectDatePreset;
  final ValueChanged<String> onRemoveEmployee;
  final ValueChanged<ReportFormat> onSelectFormat;
  final VoidCallback onGenerateReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // Scrollable Parameters Form
        Expanded(
          child: SingleChildScrollView(
            key: const Key('admin-reports-build-scrollable'),
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 1. Report Type Grid
                _buildSectionHeader('REPORT TYPE'),
                const SizedBox(height: AppSpacing.x2),
                _buildReportTypeGrid(),
                const SizedBox(height: AppSpacing.x5),

                // 2. Date Range
                _buildSectionHeader('DATE RANGE'),
                const SizedBox(height: AppSpacing.x2),
                _buildDateRangePresets(),
                const SizedBox(height: 10),
                _buildDatePreviewField(),
                const SizedBox(height: AppSpacing.x5),

                // 3. Employees
                _buildSectionHeader('EMPLOYEES'),
                const SizedBox(height: AppSpacing.x2),
                _buildEmployeesDropdown(context),
                if (state.selectedEmployees.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x2),
                  _buildSelectedEmployeePills(),
                ],
                const SizedBox(height: AppSpacing.x5),

                // 4. Format
                _buildSectionHeader('FORMAT'),
                const SizedBox(height: AppSpacing.x2),
                _buildFormatGrid(),
                const SizedBox(height: AppSpacing.x5),

                // 5. Info Banner
                _buildInfoBanner(),
                const SizedBox(height: AppSpacing.x4),
              ],
            ),
          ),
        ),

        // Pinned Bottom Action Bar
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.overline.copyWith(
        color: AppColors.neutral500,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildReportTypeGrid() {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _buildReportTypeTile(
                type: ReportType.dailyDetail,
                icon: Icons.description_outlined,
                tileKey: const Key('tile-report-type-daily'),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: _buildReportTypeTile(
                type: ReportType.employeeSummary,
                icon: Icons.person_outline_rounded,
                tileKey: const Key('tile-report-type-employee'),
              ),
            ),
          ],
        ),
        const SizedBox(width: 0, height: AppSpacing.x3),
        Row(
          children: <Widget>[
            Expanded(
              child: _buildReportTypeTile(
                type: ReportType.teamSummary,
                icon: Icons.groups_outlined,
                tileKey: const Key('tile-report-type-team'),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: _buildReportTypeTile(
                type: ReportType.visitLog,
                icon: Icons.place_outlined,
                tileKey: const Key('tile-report-type-visit'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportTypeTile({
    required ReportType type,
    required IconData icon,
    required Key tileKey,
  }) {
    final isSelected = state.reportType == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: tileKey,
        onTap: () => onSelectReportType(type),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 86,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary50 : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? AppColors.primary600 : AppColors.neutral300,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Icon(
                icon,
                size: 24,
                color: isSelected ? AppColors.primary600 : AppColors.neutral400,
              ),
              Text(
                type.title,
                style: AppTypography.label.copyWith(
                  color: isSelected ? AppColors.primary600 : AppColors.neutral600,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangePresets() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _buildDatePresetChip(
            preset: DateRangePreset.thisMonth,
            chipKey: const Key('chip-date-this-month'),
          ),
          const SizedBox(width: AppSpacing.x2),
          _buildDatePresetChip(
            preset: DateRangePreset.today,
            chipKey: const Key('chip-date-today'),
          ),
          const SizedBox(width: AppSpacing.x2),
          _buildDatePresetChip(
            preset: DateRangePreset.last7Days,
            chipKey: const Key('chip-date-last-7-days'),
          ),
          const SizedBox(width: AppSpacing.x2),
          _buildDatePresetChip(
            preset: DateRangePreset.custom,
            chipKey: const Key('chip-date-custom'),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePresetChip({
    required DateRangePreset preset,
    required Key chipKey,
  }) {
    final isSelected = state.dateRangePreset == preset;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: chipKey,
        onTap: () => onSelectDatePreset(preset),
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary600 : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: isSelected ? AppColors.primary600 : AppColors.neutral300,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            preset.label,
            style: AppTypography.label.copyWith(
              color: isSelected ? AppColors.neutral0 : AppColors.neutral600,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePreviewField() {
    return Container(
      key: const Key('field-date-preview'),
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral300, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.calendar_today_outlined,
            color: AppColors.neutral500,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              state.dateRangeText,
              style: AppTypography.body.copyWith(
                color: AppColors.neutral900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeesDropdown(BuildContext context) {
    return Container(
      key: const Key('field-employees-select'),
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral300, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Text(
              'All employees (${state.totalEmployeesCount})',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.neutral900,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.neutral400,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedEmployeePills() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: state.selectedEmployees.map((name) {
        return Container(
          key: Key('pill-employee-$name'),
          height: 28,
          padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
          decoration: BoxDecoration(
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: AppColors.primary200,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                name,
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                key: Key('btn-remove-employee-$name'),
                onTap: () => onRemoveEmployee(name),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.primary600,
                    size: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFormatGrid() {
    return Row(
      children: <Widget>[
        // PDF Option
        Expanded(
          child: _buildFormatTile(
            format: ReportFormat.pdf,
            tileKey: const Key('tile-format-pdf'),
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        // Excel Option
        Expanded(
          child: _buildFormatTile(
            format: ReportFormat.excel,
            tileKey: const Key('tile-format-excel'),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatTile({
    required ReportFormat format,
    required Key tileKey,
  }) {
    final isSelected = state.reportFormat == format;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: tileKey,
        onTap: () => onSelectFormat(format),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary50 : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? AppColors.primary600 : AppColors.neutral300,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              // Icon Badge
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surface : AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(
                  format == ReportFormat.pdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.table_chart_outlined,
                  size: 18,
                  color: isSelected
                      ? AppColors.primary600
                      : AppColors.neutral400,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      format.label,
                      style: AppTypography.label.copyWith(
                        color: isSelected
                            ? AppColors.primary600
                            : AppColors.neutral700,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    Text(
                      format.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: isSelected
                            ? AppColors.primary600.withValues(alpha: 0.8)
                            : AppColors.neutral400,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      key: const Key('reports-info-banner'),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.info,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reports are generated in English.',
              style: AppTypography.body.copyWith(
                color: AppColors.neutral900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            key: const Key('btn-generate-report'),
            onPressed: state.isGenerating ? null : onGenerateReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: AppColors.neutral0,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: state.isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.neutral0),
                    ),
                  )
                : Text(
                    'Generate report',
                    style: AppTypography.label.copyWith(
                      color: AppColors.neutral0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
