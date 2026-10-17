import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duty_time_helper.dart';
import '../../../domain/entities/duty_session.dart';
import '../../../shared/widgets/app_button.dart';

/// Screen 11: Duty-Off Summary modal card.
///
/// Presented immediately after ending duty to provide a satisfying, calm close
/// to the day. Adheres strictly to PRD F3, F4, and
/// `Design Reference/screen_11_duty_off_summary/code.html`.
class DutyOffSummaryDialog extends StatelessWidget {
  const DutyOffSummaryDialog({
    super.key,
    required this.session,
    this.onDone,
    this.onViewRoute,
    this.isSyncComplete = true,
    this.pendingSyncPoints = 0,
  });

  /// The concluded duty session details.
  final DutySession session;

  /// Callback when tapping "Done" (dismisses the dialog).
  final VoidCallback? onDone;

  /// Callback when tapping "View today's route" (navigates to route view/map).
  final VoidCallback? onViewRoute;

  /// Whether all offline telemetry batches have completed syncing.
  final bool isSyncComplete;

  /// Count of unsynced points if currently working through an offline queue.
  final int pendingSyncPoints;

  /// Presents the centered modal dialog over the active route.
  static Future<void> show(
    BuildContext context, {
    required DutySession session,
    VoidCallback? onDone,
    VoidCallback? onViewRoute,
    bool isSyncComplete = true,
    int pendingSyncPoints = 0,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.neutral900.withValues(alpha: 0.50),
      builder: (dialogContext) => DutyOffSummaryDialog(
        session: session,
        onDone: onDone ?? () => Navigator.of(dialogContext).pop(),
        onViewRoute: onViewRoute != null
            ? () {
                Navigator.of(dialogContext).pop();
                onViewRoute();
              }
            : null,
        isSyncComplete: isSyncComplete,
        pendingSyncPoints: pendingSyncPoints,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate elapsed duration
    final end = session.endedAt ?? DateTime.now().toUtc();
    final elapsed = end.difference(session.startedAt);
    final formattedInterval = DutyTimeHelper.formatShiftInterval(
      session.startedAt,
      session.endedAt,
    );
    final formattedHours = DutyTimeHelper.formatElapsed(elapsed);
    final formattedDistance =
        '${DutyTimeHelper.formatDistanceKm(session.totalDistanceKm)} km';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 358),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.neutral0,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x290F172A),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.x5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Accomplishment Badge with soft aura
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.successBg.withValues(alpha: 0.40),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.successBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.check_circle,
                        size: 36,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),

                // Header & Shift Interval
                const Text(
                  'Duty ended',
                  textAlign: TextAlign.center,
                  style: AppTypography.h2,
                ),
                const SizedBox(height: 4),
                Text(
                  formattedInterval,
                  textAlign: TextAlign.center,
                  style: AppTypography.body.withColor(AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.x2),

                // Warm Completion Note
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x3,
                      vertical: AppSpacing.x1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sentiment_satisfied,
                          size: 15,
                          color: AppColors.primary600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'SHIFT COMPLETE · REST WELL',
                          style: AppTypography.overline.copyWith(
                            color: AppColors.primary600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x6),

                // Shift Telemetry Metrics Panel
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.neutral50,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: AppColors.neutral200),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  child: Column(
                    children: [
                      // Metric Row 1: Duration
                      _MetricRow(
                        icon: Icons.schedule,
                        label: 'Total hours',
                        value: formattedHours,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.x3),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.neutral200,
                        ),
                      ),

                      // Metric Row 2: Distance Logged
                      _MetricRow(
                        icon: Icons.alt_route,
                        label: 'Distance',
                        value: formattedDistance,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.x3),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.neutral200,
                        ),
                      ),

                      // Metric Row 3: Farm Visits
                      _MetricRow(
                        icon: Icons.pin_drop,
                        label: 'Visits',
                        value: session.visitsCount.toString(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),

                // Cloud Sync Status Indicator
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSyncComplete ? Icons.check : Icons.sync,
                        size: 14,
                        color: isSyncComplete
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSyncComplete
                            ? 'All data synced'
                            : 'Queued for sync ($pendingSyncPoints points)',
                        style: AppTypography.caption.withColor(
                          AppColors.neutral400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x6),

                // Primary Done Action
                AppButton(
                  key: const Key('btn-summary-done'),
                  label: 'Done',
                  onPressed: onDone,
                  isFullWidth: true,
                ),
                const SizedBox(height: AppSpacing.x1),

                // Secondary Route Review Action
                if (onViewRoute != null)
                  SizedBox(
                    width: double.infinity,
                    height: AppSizes.controlHeight,
                    child: TextButton.icon(
                      key: const Key('btn-summary-view-route'),
                      onPressed: onViewRoute,
                      icon: const Icon(
                        Icons.map_outlined,
                        size: 18,
                        color: AppColors.primary600,
                      ),
                      label: Text(
                        "View today's route",
                        style: AppTypography.label.withColor(
                          AppColors.primary600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.neutral0,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.neutral200.withValues(alpha: 0.6),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: AppColors.neutral600),
              ),
              const SizedBox(width: AppSpacing.x2),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.withColor(AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.x2),
        Text(
          value,
          style: AppTypography.title.tabular.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
