import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/date_labels.dart';
import '../controllers/admin_reports_state.dart';

/// The report builder: what to report on, for which days, for whom, in what
/// format. Choices are locked while a report is being built.
class AdminReportsBuildView extends StatelessWidget {
  const AdminReportsBuildView({
    super.key,
    required this.state,
    required this.onSelectType,
    required this.onSelectPreset,
    required this.onPickEmployee,
  });

  final AdminReportsState state;
  final ValueChanged<ReportType> onSelectType;
  final ValueChanged<ReportPeriodPreset> onSelectPreset;
  final VoidCallback onPickEmployee;

  @override
  Widget build(BuildContext context) {
    final locked = state.isWorking;
    return SingleChildScrollView(
      key: const Key('admin-reports-build-scrollable'),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _SectionHeader('REPORT TYPE'),
          const SizedBox(height: AppSpacing.x2),
          _typeGrid(locked),
          const SizedBox(height: AppSpacing.x5),

          const _SectionHeader('DATE RANGE'),
          const SizedBox(height: AppSpacing.x2),
          _presetChips(locked),
          const SizedBox(height: 10),
          _periodReadout(),
          const SizedBox(height: AppSpacing.x5),

          const _SectionHeader('EMPLOYEE'),
          const SizedBox(height: AppSpacing.x2),
          _employeeField(locked),
          const SizedBox(height: AppSpacing.x5),

          const _SectionHeader('FORMAT'),
          const SizedBox(height: AppSpacing.x2),
          const _FormatTile(),
          const SizedBox(height: AppSpacing.x5),

          const _InfoBanner(),
          const SizedBox(height: AppSpacing.x4),
        ],
      ),
    );
  }

  Widget _typeGrid(bool locked) {
    Widget tile(ReportType type, IconData icon, String key) => Expanded(
      child: _TypeTile(
        key: Key('tile-report-type-$key'),
        type: type,
        icon: icon,
        selected: state.type == type,
        enabled: type.isAvailable && !locked,
        onTap: () => onSelectType(type),
      ),
    );
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            tile(ReportType.dailyDetail, Icons.description_outlined, 'daily'),
            const SizedBox(width: AppSpacing.x3),
            tile(
              ReportType.employeeSummary,
              Icons.person_outline_rounded,
              'employee',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        Row(
          children: <Widget>[
            tile(ReportType.teamSummary, Icons.groups_outlined, 'team'),
            const SizedBox(width: AppSpacing.x3),
            tile(ReportType.visitLog, Icons.place_outlined, 'visit'),
          ],
        ),
      ],
    );
  }

  Widget _presetChips(bool locked) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final preset in state.type.presets) ...[
            _PresetChip(
              key: Key('chip-period-${preset.name}'),
              preset: preset,
              selected: state.preset == preset,
              enabled: !locked,
              onTap: () => onSelectPreset(preset),
            ),
            const SizedBox(width: AppSpacing.x2),
          ],
        ],
      ),
    );
  }

  Widget _periodReadout() {
    final problem = state.periodProblem;
    final single = state.from == state.to;
    final text = single
        ? DateLabels.longDate(state.from)
        : '${DateLabels.dayMonthYear(state.from)} – '
              '${DateLabels.dayMonthYear(state.to)} (${state.days} days)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          key: const Key('field-date-preview'),
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: problem == null ? AppColors.neutral300 : AppColors.error,
            ),
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
                  text,
                  style: AppTypography.body.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (problem != null) ...[
          const SizedBox(height: 6),
          Text(
            problem,
            key: const Key('text-period-problem'),
            style: AppTypography.caption.copyWith(color: AppColors.errorText),
          ),
        ],
      ],
    );
  }

  Widget _employeeField(bool locked) {
    if (state.type != ReportType.employeeSummary) {
      return Container(
        key: const Key('field-employee-all'),
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.neutral300),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        child: Text(
          state.type == ReportType.visitLog
              ? 'Not available yet'
              : 'All employees',
          style: AppTypography.bodyLarge.copyWith(color: AppColors.neutral500),
        ),
      );
    }
    final chosen = state.employee;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('field-employee-select'),
        onTap: locked ? null : onPickEmployee,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: chosen == null
                  ? AppColors.neutral300
                  : AppColors.primary600,
              width: chosen == null ? 1 : 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  chosen?.label ?? 'Choose an employee',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge.copyWith(
                    color: chosen == null
                        ? AppColors.neutral500
                        : AppColors.neutral900,
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
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.overline.copyWith(
        color: AppColors.neutral500,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    super.key,
    required this.type,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ReportType type;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = type.isAvailable;
    final accent = selected ? AppColors.primary600 : AppColors.neutral600;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: '${type.title}. ${type.subtitle}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: 104,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: !available
                  ? AppColors.neutral100
                  : selected
                  ? AppColors.primary50
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? AppColors.primary600 : AppColors.neutral300,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      icon,
                      size: 24,
                      color: !available
                          ? AppColors.neutral400
                          : selected
                          ? AppColors.primary600
                          : AppColors.neutral500,
                    ),
                    const Spacer(),
                    if (!available)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.neutral200,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          'SOON',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.neutral600,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      type.title,
                      style: AppTypography.label.copyWith(
                        color: available ? accent : AppColors.neutral500,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    Text(
                      type.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    super.key,
    required this.preset,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ReportPeriodPreset preset;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary600 : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: selected ? AppColors.primary600 : AppColors.neutral300,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (preset.needsPicker) ...[
                Icon(
                  Icons.edit_calendar_outlined,
                  size: 15,
                  color: selected ? AppColors.neutral0 : AppColors.neutral500,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                preset.label,
                style: AppTypography.label.copyWith(
                  color: selected ? AppColors.neutral0 : AppColors.neutral600,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PDF is the only format there is; Excel is added when it exists.
class _FormatTile extends StatelessWidget {
  const _FormatTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('tile-format-pdf'),
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary600, width: 2),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 20,
              color: AppColors.primary600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PDF',
                  style: AppTypography.label.copyWith(
                    color: AppColors.primary600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Printable report, A4',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.primary600,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
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
              'Reports are in English. Every report you create is recorded in '
              'the audit log, and contains personal data: share it with care.',
              style: AppTypography.body.copyWith(color: AppColors.neutral900),
            ),
          ),
        ],
      ),
    );
  }
}
