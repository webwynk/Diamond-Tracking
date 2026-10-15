import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import 'controllers/admin_route_view_controller.dart';
import 'controllers/admin_route_view_state.dart';
import 'widgets/admin_route_date_pill.dart';
import 'widgets/admin_route_floating_app_bar.dart';
import 'widgets/admin_route_map_view.dart';
import 'widgets/admin_route_summary_sheet.dart';

/// Screen 23 — Route View (Admin).
///
/// An authoritative static picture of one field employee's entire day drawn
/// on a cartographic road map with verified telemetry totals.
///
/// Per explicit PRD requirements:
/// - Static route view, NOT a video player (zero playback controls, zero scrubbers, zero speed chips).
/// - Upper 62%: Light-styled road map with 4px #016893 route hero polyline,
///   32px start flag (#16A34A), 32px end square (#1E293B), 5 visit pins (1-5),
///   2 long stops (#F59E0B dashed), 1 red anomaly marker (#DC2626) with dashed red segment,
///   and a 500m geofence circle around Visit 3.
/// - Floating top app bar: white card inset 16 dp, #016893 back chevron,
///   "Route" title + "Suresh Patel · Sat, 11 Oct", and share icon.
/// - Centered date selector pill: "< Sat, 11 Oct >".
/// - Lower 38%: White sheet with drag handle, 4 stat blocks (Distance, Duty hours,
///   Visits, Flag), inline meta (shift time, 2 long stops), red alert strip,
///   and full-width "View visits" outlined button.
class AdminRouteViewPage extends ConsumerWidget {
  const AdminRouteViewPage({
    super.key,
    this.employeeId = 'emp-1',
    this.dayId,
    this.onBack,
  });

  final String employeeId;
  final String? dayId;
  final VoidCallback? onBack;

  void _showFlagDetailsDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: Text(
                'Flagged Telemetry Anomaly',
                style: AppTypography.title.copyWith(color: AppColors.neutral900),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time: 4:40 PM · GPS Jump / Mock Provider',
              style: AppTypography.label.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Location coordinate leaped 8.4 km in 2 seconds with 0 m accuracy variance. Point excluded from payable distance calculation pursuant to telemetry verification policy.',
              style: AppTypography.body.copyWith(
                color: AppColors.neutral700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            Container(
              padding: const EdgeInsets.all(AppSpacing.x3),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.security_rounded,
                    size: 16,
                    color: AppColors.neutral600,
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      'Flag ID: FLG-20261011-0440 · Audit Verified',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showVisitsBottomSheet(
    BuildContext context,
    List<AdminRouteWaypoint> waypoints,
  ) {
    final visitWaypoints = waypoints
        .where((w) => w.type == AdminWaypointType.visit)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            12,
            AppSpacing.x4,
            AppSpacing.x4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recorded Visits (5)',
                    style: AppTypography.title.copyWith(
                      color: AppColors.neutral900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Sat, 11 Oct',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),
              ...visitWaypoints.map((visit) {
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.x2),
                  padding: const EdgeInsets.all(AppSpacing.x3),
                  decoration: BoxDecoration(
                    color: AppColors.neutral50,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.neutral200, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppColors.primary600,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${visit.visitNumber ?? 1}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.neutral0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visit.title,
                              style: AppTypography.label.copyWith(
                                color: AppColors.neutral900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              visit.subtitle,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.neutral500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        visit.time,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminRouteViewControllerProvider);
    final notifier = ref.read(adminRouteViewControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          // Main Body Column: Upper 62% Map + Lower 38% Telemetry Sheet
          Column(
            children: <Widget>[
              // Upper 62% Route Map View
              Expanded(
                flex: 62,
                child: AdminRouteMapView(
                  waypoints: state.waypoints,
                  isSatellite: state.isMapSatellite,
                  showFlagExcludedRoute: state.showFlagExcludedRoute,
                  selectedWaypointId: state.selectedWaypointId,
                  onWaypointTapped: (waypoint) {
                    notifier.selectWaypoint(waypoint.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${waypoint.title} (${waypoint.time})',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  onFitRoute: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Route centered to full 47.3 km corridor.',
                        ),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  onToggleLayers: () {
                    notifier.toggleSatellite();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          state.isMapSatellite
                              ? 'Default topographic basemap enabled.'
                              : 'Satellite imagery basemap enabled.',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),

              // Lower 38% Telemetry Audit Bottom Sheet
              AdminRouteSummarySheet(
                telemetry: state.telemetry,
                onViewFlagDetails: () => _showFlagDetailsDialog(context, ref),
                onViewVisitsList: () => _showVisitsBottomSheet(
                  context,
                  state.waypoints,
                ),
              ),
            ],
          ),

          // Floating Top Controls (App Bar + Centered Date Pill)
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 8),

                // 1. Floating Inset App Bar
                AdminRouteFloatingAppBar(
                  title: 'Route',
                  subtitle: '${state.employeeName} · ${state.selectedDateText}',
                  onBack: onBack ?? () => Navigator.of(context).maybePop(),
                  onShare: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Sharing ${state.employeeName}\'s route for ${state.selectedDateText}...',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),

                // 2. Horizontally Centered Date Selector Pill
                AdminRouteDatePill(
                  selectedDateText: state.selectedDateText,
                  onPreviousDate: notifier.previousDate,
                  onNextDate: notifier.nextDate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
