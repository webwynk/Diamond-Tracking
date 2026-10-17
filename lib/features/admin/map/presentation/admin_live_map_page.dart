import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../dashboard/presentation/widgets/admin_profile_sheet.dart';
import '../../notifications/presentation/admin_notification_centre_page.dart';
import '../../notifications/presentation/controllers/admin_notification_controller.dart';
import '../../route_view/presentation/admin_route_view_page.dart';
import 'controllers/admin_live_map_controller.dart';
import 'controllers/admin_live_map_state.dart';
import 'widgets/admin_map_filter_chips_bar.dart';
import 'widgets/admin_map_floating_controls.dart';
import 'widgets/admin_map_search_bar.dart';
import 'widgets/live_connection_badge.dart';
import 'widgets/live_officer_card.dart';
import 'widgets/live_officer_list_sheet.dart';
import 'widgets/live_officers_map.dart';

/// Screen 15 — Admin Live Map.
///
/// Every employee who is on duty, as a dot at their latest position, updated as
/// the positions arrive. Tap a dot for the person, tap a cluster to zoom in.
/// Off-duty and blocked employees have no position and are not drawn (the Team
/// list shows them).
class AdminLiveMapPage extends ConsumerStatefulWidget {
  const AdminLiveMapPage({super.key, this.onNavigateToNotifications});

  final VoidCallback? onNavigateToNotifications;

  @override
  ConsumerState<AdminLiveMapPage> createState() => _AdminLiveMapPageState();
}

class _AdminLiveMapPageState extends ConsumerState<AdminLiveMapPage> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<LiveOfficersMapState> _mapKey =
      GlobalKey<LiveOfficersMapState>();

  @override
  void initState() {
    super.initState();
    // A request made before this tab was ever opened (Track live from a
    // profile) is waiting already.
    WidgetsBinding.instance.addPostFrameCallback((_) => _answerFocusRequest());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Answers a "show this employee" request (Track live on a profile): opens
  /// their card and zooms to them. A request for someone who is not on the map
  /// once the positions have loaded is dropped, not kept forever.
  void _answerFocusRequest() {
    if (!mounted) return;
    final id = ref.read(liveMapFocusProvider);
    if (id == null) return;
    final state = ref.read(adminLiveMapControllerProvider);
    if (state.isLoading) return;
    final notifier = ref.read(adminLiveMapControllerProvider.notifier);
    final matches = state.officers.where((o) => o.id == id);
    ref.read(liveMapFocusProvider.notifier).clear();
    if (matches.isEmpty) return;
    // A search or chip could be hiding that dot.
    notifier
      ..clearFilters()
      ..select(id);
    _searchController.clear();
    _mapKey.currentState?.flyTo(matches.first.position);
  }

  void _openNotifications() {
    final override = widget.onNavigateToNotifications;
    if (override != null) {
      override();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdminNotificationCentrePage(),
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    ref.read(adminLiveMapControllerProvider.notifier).clearFilters();
  }

  void _showList(AdminLiveMapState state) {
    LiveOfficerListSheet.show(
      context,
      officers: state.filteredOfficers,
      onSelected: (officer) {
        ref.read(adminLiveMapControllerProvider.notifier).select(officer.id);
        _mapKey.currentState?.flyTo(officer.position);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(adminLiveMapControllerProvider);
    final notifier = ref.read(adminLiveMapControllerProvider.notifier);
    ref.listen(liveMapFocusProvider, (_, _) => _answerFocusRequest());
    ref.listen(
      adminLiveMapControllerProvider.select((s) => s.isLoading),
      (_, _) => _answerFocusRequest(),
    );
    final shown = mapState.filteredOfficers;
    final selected = mapState.selectedOfficer;
    final loaded = !mapState.isLoading && mapState.errorMessage == null;
    final unreadNotifications = ref.watch(
      adminNotificationControllerProvider.select((s) => s.unreadCount),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        style: AppTopBarStyle.brand,
        title: 'Live Map',
        subtitle: 'Diamond Agritech',
        actions: <Widget>[
          AppTopBarIconButton(
            key: const Key('btn-telemetry-notifications-action'),
            icon: Icons.notifications_none_rounded,
            tooltip: 'Alerts',
            badgeCount: unreadNotifications,
            onPressed: _openNotifications,
          ),
          AppTopBarProfileButton(
            tooltip: 'Admin profile',
            onPressed: () => AdminProfileSheet.show(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: <Widget>[
            // 1. The map, with a dot per employee on duty.
            Positioned.fill(
              child: LiveOfficersMap(
                key: _mapKey,
                officers: shown,
                selectedId: selected?.id,
                onOfficerTapped: notifier.select,
              ),
            ),

            // 2. Honest states: loading, failed, nobody on duty, filtered out.
            if (mapState.isLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66FFFFFF),
                  child: Center(
                    child: CircularProgressIndicator(
                      key: Key('live-map-loading'),
                    ),
                  ),
                ),
              ),
            if (mapState.errorMessage != null)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.background,
                  child: AppErrorView(
                    title: "Couldn't load the live map",
                    message: mapState.errorMessage!,
                    onRetry: notifier.retry,
                  ),
                ),
              ),
            if (loaded && mapState.officers.isEmpty)
              Center(child: AppEmptyState.nobodyOnDuty()),
            if (loaded && mapState.officers.isNotEmpty && shown.isEmpty)
              Center(
                child: AppEmptyState.filteredToNothing(
                  onClearFilters: _clearFilters,
                ),
              ),

            // 3. Top: search, status filters, connection.
            Positioned(
              top: AppSpacing.x3,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x4,
                    ),
                    child: AdminMapSearchBar(
                      controller: _searchController,
                      onChanged: notifier.setSearchQuery,
                      onClear: () {
                        _searchController.clear();
                        notifier.setSearchQuery('');
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  AdminMapFilterChipsBar(
                    selectedFilter: mapState.selectedFilter,
                    totalCount: mapState.totalCount,
                    onDutyCount: mapState.onDutyCount,
                    staleCount: mapState.staleCount,
                    needsCheckCount: mapState.needsCheckCount,
                    onFilterSelected: notifier.setFilter,
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  if (loaded)
                    LiveConnectionBadge(connection: mapState.connection),
                ],
              ),
            ),

            // 4. Bottom: map tools, and the card of the tapped employee.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AdminMapFloatingControls(
                    onRecenter: () => _mapKey.currentState?.fitToOfficers(),
                    onToggleListView: () => _showList(mapState),
                  ),
                  if (selected != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x4,
                        0,
                        AppSpacing.x4,
                        AppSpacing.x3,
                      ),
                      child: LiveOfficerCard(
                        officer: selected,
                        onClose: () => notifier.select(null),
                        onZoomTo: () =>
                            _mapKey.currentState?.flyTo(selected.position),
                        onViewRoute: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AdminRouteViewPage(
                              employeeId: selected.id,
                              employeeName: selected.name,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
