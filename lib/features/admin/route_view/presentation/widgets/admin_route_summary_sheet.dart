import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/duty_time_helper.dart';
import '../controllers/admin_route_view_state.dart';

/// Totals of the day under the route map (Screen 23).
///
/// Every figure is the server's: distance and counts from the session rows,
/// hours from their start and end times. Nothing is measured on the phone.
class AdminRouteSummarySheet extends StatelessWidget {
  const AdminRouteSummarySheet({
    super.key,
    required this.summary,
    required this.showLegend,
    required this.showCurrent,
  });

  final RouteSummary summary;

  /// A route is drawn, so explain its markers.
  final bool showLegend;

  /// The last marker is the current position rather than the end.
  final bool showCurrent;

  @override
  Widget build(BuildContext context) {
    final distance = summary.distanceKm;
    final flagged = summary.flaggedPoints;
    final weakGps = summary.weakGpsPoints;
    return Container(
      key: const Key('route-summary-sheet'),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border(top: BorderSide(color: AppColors.neutral200, width: 1)),
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
        AppSpacing.x4,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
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

            // Four stat blocks.
            Container(
              decoration: BoxDecoration(
                color: AppColors.neutral50,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.neutral200, width: 1),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _stat(
                      key: 'route-stat-distance',
                      value: distance == null
                          ? '—'
                          : '${DutyTimeHelper.formatDistanceKm(distance)} km',
                      label: 'Distance',
                    ),
                  ),
                  _divider(),
                  Expanded(
                    child: _stat(
                      key: 'route-stat-hours',
                      value: DutyTimeHelper.formatElapsed(summary.dutyDuration),
                      label: summary.hasOpenSession
                          ? 'Duty hours so far'
                          : 'Duty hours',
                    ),
                  ),
                  _divider(),
                  Expanded(
                    child: _stat(
                      key: 'route-stat-visits',
                      value: '${summary.visitsCount}',
                      label: 'Visits',
                    ),
                  ),
                  _divider(),
                  Expanded(
                    child: _stat(
                      key: 'route-stat-flagged',
                      value: '$flagged',
                      label: 'Flagged',
                      colour: flagged > 0 ? AppColors.error : null,
                    ),
                  ),
                ],
              ),
            ),
            if (distance == null && summary.hasOpenSession) ...<Widget>[
              const SizedBox(height: AppSpacing.x2),
              Text(
                'The running distance is not available yet.',
                key: const Key('route-distance-unavailable'),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.x3),

            // Shift time and how it ended.
            Row(
              children: <Widget>[
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppColors.neutral500,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    summary.sessionCount > 1
                        ? '${summary.shiftTimeRange} · ${summary.sessionCount} sessions'
                        : summary.shiftTimeRange,
                    key: const Key('route-shift-range'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (summary.endNote != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.x3),
                  Flexible(
                    child: Text(
                      summary.endNote!,
                      key: const Key('route-end-note'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Real warnings (fake location, impossible jumps), in words.
            if (flagged > 0 || summary.jumpCount > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.x3),
              _banner(
                key: const Key('route-flag-note'),
                background: AppColors.errorBg,
                border: AppColors.error.withValues(alpha: 0.25),
                icon: Icons.warning_amber_rounded,
                iconColour: AppColors.error,
                text: _flagNote(),
              ),
            ],

            // A weak GPS signal is noise, not a warning: calm and neutral.
            if (weakGps > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.x3),
              _banner(
                key: const Key('route-weak-gps-note'),
                background: AppColors.neutral50,
                border: AppColors.neutral200,
                icon: Icons.info_outline_rounded,
                iconColour: AppColors.neutral500,
                text: _weakGpsNote(),
              ),
            ],

            if (showLegend) ...<Widget>[
              const SizedBox(height: AppSpacing.x3),
              Wrap(
                key: const Key('route-legend'),
                spacing: AppSpacing.x3,
                runSpacing: AppSpacing.x1,
                children: <Widget>[
                  _legend(AppColors.statusActive, 'Start'),
                  _legend(
                    showCurrent
                        ? AppColors.primary600
                        : AppColors.statusBlocked,
                    showCurrent ? 'Now' : 'End',
                  ),
                  if (flagged > 0)
                    _legend(AppColors.statusSuspect, 'Fake location'),
                  if (weakGps > 0) _legend(AppColors.statusStale, 'Weak GPS'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _flagNote() {
    final parts = <String>[
      if (summary.flaggedPoints > 0)
        '${summary.flaggedPoints} fake-location '
            '${summary.flaggedPoints == 1 ? 'point is' : 'points are'} '
            'left out of the route and the distance',
      if (summary.jumpCount > 0)
        '${summary.jumpCount} impossible '
            '${summary.jumpCount == 1 ? 'jump' : 'jumps'} not drawn as travel',
    ];
    return '${parts.join('. ')}.';
  }

  String _weakGpsNote() {
    final n = summary.weakGpsPoints;
    return '$n weak GPS ${n == 1 ? 'reading was' : 'readings were'} left out '
        'of the route and the distance. This is normal, for example just '
        'after duty starts or indoors.';
  }

  Widget _banner({
    required Key key,
    required Color background,
    required Color border,
    required IconData icon,
    required Color iconColour,
    required String text,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: 10,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: iconColour, size: 18),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption.copyWith(
                color: AppColors.neutral900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color colour, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _stat({
    required String key,
    required String value,
    required String label,
    Color? colour,
  }) {
    return Column(
      key: Key(key),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.title.copyWith(
            color: colour ?? AppColors.neutral900,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(color: AppColors.neutral500),
        ),
      ],
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 28, color: AppColors.neutral200);
}
