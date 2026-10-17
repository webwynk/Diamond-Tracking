import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import 'controllers/admin_route_view_controller.dart';
import 'controllers/admin_route_view_state.dart';
import 'widgets/admin_route_date_pill.dart';
import 'widgets/admin_route_map_view.dart';
import 'widgets/admin_route_summary_sheet.dart';

/// Screen 23 — Route View (Admin).
///
/// One employee's day as a static picture (docs/07 section 4, PRD F8): the
/// stored route drawn as a highlighted line on the real map, with start and end
/// (or current position) and the flagged points on their own, and the totals
/// underneath. No playback, no scrubber, no speed control, no animation.
///
/// Totals come from the server's session rows; the drawn line is simplified for
/// display only. A day older than 30 days has no route but still has its
/// totals. Every state is explicit: loading, failed, no duty, no usable point,
/// expired.
class AdminRouteViewPage extends ConsumerStatefulWidget {
  const AdminRouteViewPage({
    super.key,
    required this.employeeId,
    required this.employeeName,
    this.dayId,
    this.onBack,
  });

  final String employeeId;
  final String employeeName;

  /// A day to open on, as `yyyy-MM-dd` (IST). Anything else opens on today.
  final String? dayId;
  final VoidCallback? onBack;

  @override
  ConsumerState<AdminRouteViewPage> createState() => _AdminRouteViewPageState();
}

class _AdminRouteViewPageState extends ConsumerState<AdminRouteViewPage> {
  final GlobalKey<AdminRouteMapViewState> _mapKey =
      GlobalKey<AdminRouteMapViewState>();

  late final RouteViewArgs _args = RouteViewArgs(
    employeeId: widget.employeeId,
    initialDate: _parseDay(widget.dayId),
  );

  static final RegExp _dayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static DateTime? _parseDay(String? dayId) {
    if (dayId == null || !_dayPattern.hasMatch(dayId)) return null;
    final parsed = DateTime.tryParse(dayId);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminRouteViewControllerProvider(_args));
    final notifier = ref.read(adminRouteViewControllerProvider(_args).notifier);
    final summary = state.summary;
    final drawn = state.load == RouteLoad.loaded && !state.isExpired;
    final showCurrent = state.isToday && (summary?.hasOpenSession ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        leading: AppTopBarLeading.back,
        leadingKey: const Key('btn-route-back'),
        onLeadingPressed: widget.onBack,
        title: 'Route',
        subtitle: '${widget.employeeName} · ${state.selectedDateText}',
        actions: <Widget>[
          IconButton(
            key: const Key('btn-route-refresh'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload this day',
            onPressed: notifier.reload,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: AdminRouteMapView(
                    key: _mapKey,
                    analysis: drawn ? state.analysis : null,
                    showCurrent: showCurrent,
                  ),
                ),

                // Honest states over the map.
                if (state.load == RouteLoad.loading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66FFFFFF),
                      child: Center(
                        child: CircularProgressIndicator(
                          key: Key('route-loading'),
                        ),
                      ),
                    ),
                  ),
                if (state.load == RouteLoad.failed)
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppColors.background,
                      child: AppErrorView(
                        key: const Key('route-error'),
                        title: "Couldn't load the route",
                        message: state.errorMessage ?? '',
                        onRetry: notifier.reload,
                      ),
                    ),
                  ),
                if (state.hasNoDuty)
                  _overlay(
                    AppEmptyState.noRoute(dateLabel: state.selectedDateText),
                  ),
                if (state.load == RouteLoad.loaded &&
                    state.isExpired &&
                    summary != null)
                  _overlay(AppEmptyState.routeExpired()),
                if (state.hasNoRoute)
                  _overlay(
                    const AppEmptyState(
                      icon: Icons.location_off_outlined,
                      title: 'No usable location',
                      description:
                          'Duty was recorded, but the phone sent no location '
                          'that can be drawn.',
                    ),
                  ),
                if (state.day?.truncated ?? false)
                  Positioned(
                    left: AppSpacing.x4,
                    right: AppSpacing.x4,
                    bottom: AppSpacing.x3,
                    child: Container(
                      key: const Key('route-truncated'),
                      padding: const EdgeInsets.all(AppSpacing.x2),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Text(
                        'This day has more points than can be shown. The '
                        'route is drawn from the first part of the day.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                // Date selector floating over the map.
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.x2),
                    child: AdminRouteDatePill(
                      selectedDateText: state.selectedDateText,
                      onPreviousDate: notifier.previousDate,
                      onNextDate: notifier.nextDate,
                    ),
                  ),
                ),

                // Fit the whole route again, on request.
                if (drawn && (state.analysis?.hasAnythingToDraw ?? false))
                  Positioned(
                    right: AppSpacing.x4,
                    top: AppSpacing.x2 + 48,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.neutral200),
                      ),
                      child: IconButton(
                        key: const Key('btn-route-fit'),
                        icon: const Icon(
                          Icons.fit_screen_rounded,
                          color: AppColors.primary600,
                        ),
                        tooltip: 'Show the whole route',
                        onPressed: () => _mapKey.currentState?.fit(),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (summary != null)
            AdminRouteSummarySheet(
              summary: summary,
              showLegend: drawn && (state.analysis?.hasAnythingToDraw ?? false),
              showCurrent: showCurrent,
            ),
        ],
      ),
    );
  }

  Widget _overlay(Widget child) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(alignment: const Alignment(0, -0.2), child: child),
      ),
    );
  }
}
