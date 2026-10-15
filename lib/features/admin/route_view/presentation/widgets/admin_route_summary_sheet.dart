import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_route_view_state.dart';

/// Lower 38% route telemetry and audit summary sheet for Screen 23 Route View (Admin).
class AdminRouteSummarySheet extends StatelessWidget {
  const AdminRouteSummarySheet({
    super.key,
    required this.telemetry,
    required this.onViewFlagDetails,
    required this.onViewVisitsList,
  });

  final AdminRouteTelemetry telemetry;
  final VoidCallback onViewFlagDetails;
  final VoidCallback onViewVisitsList;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border(
          top: BorderSide(color: AppColors.neutral200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        12,
        AppSpacing.x4,
        AppSpacing.x5,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. Centered Drag Handle
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x3),

            // 2. Row of Four Stat Blocks Divided by 1px Verticals
            Container(
              decoration: BoxDecoration(
                color: AppColors.neutral50,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.neutral200, width: 1),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: <Widget>[
                  // Stat 1: Distance
                  Expanded(
                    child: _buildStatBlock(
                      value: telemetry.distanceKm,
                      label: 'Distance',
                      valueColor: AppColors.neutral900,
                    ),
                  ),
                  _buildVerticalDivider(),

                  // Stat 2: Duty hours
                  Expanded(
                    child: _buildStatBlock(
                      value: telemetry.dutyHours,
                      label: 'Duty hours',
                      valueColor: AppColors.neutral900,
                    ),
                  ),
                  _buildVerticalDivider(),

                  // Stat 3: Visits
                  Expanded(
                    child: _buildStatBlock(
                      value: '${telemetry.visitsCount}',
                      label: 'Visits',
                      valueColor: AppColors.neutral900,
                    ),
                  ),
                  _buildVerticalDivider(),

                  // Stat 4: Flag
                  Expanded(
                    child: _buildStatBlock(
                      value: '${telemetry.flagsCount}',
                      label: 'Flag',
                      valueColor: AppColors.error,
                      isBold: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x3),

            // 3. Row of Two Inline Meta Items
            Row(
              children: <Widget>[
                // Shift range
                Expanded(
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: AppColors.neutral500,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          telemetry.shiftTimeRange,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.neutral600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Long stops count
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.pause_circle_outline_rounded,
                      size: 16,
                      color: AppColors.neutral500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      telemetry.stopsSummary,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),

            // 4. Flagged Point Alert Strip (#FEE2E2)
            Container(
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x3,
                vertical: 10,
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      telemetry.flagNote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  InkWell(
                    key: const Key('btn-route-view-flag'),
                    onTap: onViewFlagDetails,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        'View',
                        style: AppTypography.label.copyWith(
                          color: AppColors.primary600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x3),

            // 5. Full-Width Outlined Button: "View visits"
            OutlinedButton.icon(
              key: const Key('btn-route-view-visits'),
              onPressed: onViewVisitsList,
              icon: const Icon(
                Icons.format_list_bulleted_rounded,
                size: 18,
                color: AppColors.primary600,
              ),
              label: Text(
                'View visits',
                style: AppTypography.label.copyWith(
                  color: AppColors.primary600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary600,
                side: const BorderSide(color: AppColors.primary600, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBlock({
    required String value,
    required String label,
    required Color valueColor,
    bool isBold = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.title.copyWith(
            color: valueColor,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: AppColors.neutral500,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.neutral200,
    );
  }
}
