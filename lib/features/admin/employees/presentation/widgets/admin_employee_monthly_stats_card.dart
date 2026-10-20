import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/date_labels.dart';
import 'admin_profile_section.dart';

/// Screen 18 "This month": a month picker, four stat tiles and two status
/// chips. The chips are grey when there is nothing to worry about and tinted
/// only when there is (docs/03 principle 6, calm by default).
class AdminEmployeeMonthlyStatsCard extends StatelessWidget {
  const AdminEmployeeMonthlyStatsCard({
    super.key,
    this.monthName,
    this.daysWorked = 0,
    this.hoursWorked = '0h 00m',
    this.distanceKm = '0.0 km',
    this.visitsCount = 0,
    this.autoEndedDays = 0,
    this.locationFlags = 0,
    this.isAvailable = true,
    this.onMonthSelect,
  });

  /// Month shown on the chip. Defaults to the current month.
  final String? monthName;
  final int daysWorked;
  final String hoursWorked;
  final String distanceKm;
  final int visitsCount;
  final int autoEndedDays;
  final int locationFlags;

  /// False while the month is loading or could not be loaded: the figures show
  /// a dash instead of a made-up zero.
  final bool isAvailable;
  final VoidCallback? onMonthSelect;

  @override
  Widget build(BuildContext context) {
    String figure(String value) => isAvailable ? value : '–';

    return AdminProfileSection(
      title: 'This month',
      trailing: _MonthChip(
        label: monthName ?? DateLabels.monthName(DateTime.now()),
        onTap: onMonthSelect,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _StatTile(
                  key: const Key('metric-days-worked'),
                  icon: Icons.calendar_today_rounded,
                  value: figure('$daysWorked'),
                  label: 'Days worked',
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: _StatTile(
                  key: const Key('metric-hours-worked'),
                  icon: Icons.schedule_rounded,
                  value: figure(hoursWorked),
                  label: 'Hours',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatTile(
                  key: const Key('metric-distance-km'),
                  icon: Icons.route_rounded,
                  value: figure(distanceKm),
                  label: 'Distance',
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: _StatTile(
                  key: const Key('metric-visits-count'),
                  icon: Icons.storefront_rounded,
                  value: figure('$visitsCount'),
                  label: 'Visits',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: <Widget>[
              AdminProfileStatusChip(
                key: const Key('chip-auto-ended'),
                icon: Icons.timer_off_outlined,
                label: isAvailable
                    ? '$autoEndedDays ${autoEndedDays == 1 ? 'day' : 'days'} auto-ended'
                    : 'auto-ended days: –',
                background: isAvailable && autoEndedDays > 0
                    ? AppColors.warningBg
                    : AppColors.neutral100,
                foreground: isAvailable && autoEndedDays > 0
                    ? AppColors.warningText
                    : AppColors.neutral600,
              ),
              AdminProfileStatusChip(
                key: const Key('chip-location-flags'),
                icon: Icons.wrong_location_outlined,
                label: isAvailable
                    ? '$locationFlags location ${locationFlags == 1 ? 'flag' : 'flags'}'
                    : 'location flags: –',
                background: isAvailable && locationFlags > 0
                    ? AppColors.errorBg
                    : AppColors.neutral100,
                foreground: isAvailable && locationFlags > 0
                    ? AppColors.errorText
                    : AppColors.neutral600,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The tonal month picker on the title row, with a full touch target.
class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('btn-employee-select-month'),
      onTap: onTap,
      borderRadius: AppRadius.fullAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3,
              vertical: AppSpacing.x1,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary50,
              borderRadius: AppRadius.fullAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: AppTypography.label.withColor(AppColors.primary700),
                ),
                const SizedBox(width: AppSpacing.x1),
                const Icon(
                  Icons.expand_more_rounded,
                  size: AppSizes.iconDense,
                  color: AppColors.primary700,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: AppSizes.iconDense, color: AppColors.primary600),
          const SizedBox(height: AppSpacing.x2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.h2.tabular.withColor(AppColors.textPrimary),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.withColor(AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
