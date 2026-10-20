import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../employees/presentation/admin_employee_form_page.dart';
import '../../map/presentation/controllers/admin_live_map_controller.dart';
import '../../map/presentation/controllers/admin_live_map_state.dart';
import '../../notifications/presentation/admin_notification_centre_page.dart';
import '../../notifications/presentation/controllers/admin_notification_controller.dart';
import '../../shell/admin_tab.dart';
import 'controllers/admin_attention.dart';
import 'controllers/admin_dashboard_controller.dart';
import 'widgets/admin_attention_card.dart';
import 'widgets/admin_map_preview_card.dart';
import 'widgets/admin_profile_sheet.dart';
import 'widgets/admin_quick_actions.dart';
import 'widgets/admin_recent_activity_card.dart';
import 'widgets/admin_stat_card.dart';

/// Screen 14 — Admin Home / Dashboard
///
/// Serves as the central command console for office administrators, answering
/// "Who is working right now?" in under two seconds: an operational status strip,
/// a 2x2 live telemetry matrix (On duty, Off duty, No update, Needs check),
/// attention alerts, quick shortcuts, the live map preview, and recent activity.
/// Every figure comes from the live feed and the server; an unknown figure is a dash,
/// never a zero.
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({
    super.key,
    this.onNavigateToNotifications,
    this.onProfilePressed,
  });

  final VoidCallback? onNavigateToNotifications;
  final VoidCallback? onProfilePressed;

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  void _selectTab(AdminTab tab) =>
      ref.read(adminTabProvider.notifier).select(tab);

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

  /// Pull to refresh: the live positions, activity feed, and notifications together.
  Future<void> _refresh() {
    return Future.wait<void>([
      ref.read(adminLiveMapControllerProvider.notifier).refresh(),
      ref.read(adminDashboardControllerProvider.notifier).refresh(),
      ref.read(adminNotificationControllerProvider.notifier).refresh(),
    ]);
  }

  void _openAttention(AttentionItem item) {
    ref.read(liveMapFocusProvider.notifier).request(item.officer.id);
    _selectTab(AdminTab.map);
  }

  void _addEmployee() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminEmployeeFormPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(adminDashboardControllerProvider);
    // The same live feed as the Map tab, so the two always agree.
    final live = ref.watch(adminLiveMapControllerProvider);
    final liveLoaded = !live.isLoading && live.errorMessage == null;
    String count(int? value) => liveLoaded && value != null ? '$value' : '–';
    final unreadNotifications = ref.watch(
      adminNotificationControllerProvider.select((s) => s.unreadCount),
    );

    final now = DateTime.now();

    final offDuty = live.offDutyCount;
    final totalActive = liveLoaded && offDuty != null
        ? live.totalCount + offDuty
        : null;
    final attention = liveLoaded
        ? attentionItems(live.officers)
        : const <AttentionItem>[];
    final stale = liveLoaded ? live.staleCount : 0;
    final needsCheck = liveLoaded ? live.needsCheckCount : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        style: AppTopBarStyle.brand,
        title: 'Diamond Agritech',
        subtitle: 'Admin • Home',
        actions: <Widget>[
          AppTopBarIconButton(
            key: const Key('admin-notifications-btn'),
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            badgeCount: unreadNotifications,
            onPressed: _openNotifications,
          ),
          AppTopBarProfileButton(
            key: const Key('admin-profile-btn'),
            tooltip: 'Admin profile',
            onPressed:
                widget.onProfilePressed ??
                () => AdminProfileSheet.show(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x4,
                    AppSpacing.x3,
                    AppSpacing.x4,
                    AppSpacing.x2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          DateLabels.longDate(now),
                          key: const Key('dashboard-date'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      _DashboardConnectionBadge(connection: live.connection),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AdminStatCard(
                              key: const Key('dashboard-on-duty'),
                              value: count(live.totalCount),
                              valueKey: const Key('dashboard-on-duty-count'),
                              label: 'ON DUTY',
                              subtitle: totalActive != null
                                  ? 'of $totalActive active'
                                  : null,
                              subtitleKey: const Key('dashboard-of-total'),
                              icon: Icons.badge_outlined,
                              badgeColor: AppColors.primary100,
                              iconColor: AppColors.primary600,
                              onTap: () => _selectTab(AdminTab.map),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.x3),
                          Expanded(
                            child: AdminStatCard(
                              value: count(live.offDutyCount),
                              label: 'OFF DUTY',
                              icon: Icons.person_off_rounded,
                              badgeColor: AppColors.neutral100,
                              iconColor: AppColors.textDisabled,
                              onTap: () => _selectTab(AdminTab.team),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      Row(
                        children: [
                          Expanded(
                            child: AdminStatCard(
                              value: count(live.staleCount),
                              label: 'NO UPDATE',
                              icon: Icons.signal_wifi_off_rounded,
                              badgeColor: AppColors.warningBg,
                              iconColor: AppColors.warning,
                              borderColor: stale > 0
                                  ? AppColors.warning
                                  : AppColors.neutral200,
                              labelColor: stale > 0
                                  ? AppColors.warningText
                                  : AppColors.textSecondary,
                              showPingDot: stale > 0,
                              pingColor: AppColors.warning,
                              onTap: () => _selectTab(AdminTab.team),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.x3),
                          Expanded(
                            child: AdminStatCard(
                              value: count(live.needsCheckCount),
                              label: 'NEEDS CHECK',
                              icon: Icons.warning_amber_rounded,
                              badgeColor: AppColors.errorBg,
                              iconColor: AppColors.error,
                              borderColor: needsCheck > 0
                                  ? AppColors.error
                                  : AppColors.neutral200,
                              labelColor: needsCheck > 0
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              showPingDot: needsCheck > 0,
                              pingColor: AppColors.error,
                              onTap: () => _selectTab(AdminTab.team),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      if (attention.isNotEmpty) ...[
                        AdminAttentionCard(
                          items: attention,
                          onOpen: _openAttention,
                        ),
                        const SizedBox(height: AppSpacing.x4),
                      ],
                      AdminQuickActions(
                        onLiveMap: () => _selectTab(AdminTab.map),
                        onTeam: () => _selectTab(AdminTab.team),
                        onReports: () => _selectTab(AdminTab.reports),
                        onAddEmployee: _addEmployee,
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      AdminMapPreviewCard(
                        officers: live.officers,
                        isLoading: live.isLoading,
                        errorMessage: live.errorMessage,
                        onViewMap: () => _selectTab(AdminTab.map),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      AdminRecentActivityCard(
                        activities: dashboardState.activities,
                        isLoading: dashboardState.isLoading,
                        errorMessage: dashboardState.errorMessage,
                        onRetry: ref
                            .read(adminDashboardControllerProvider.notifier)
                            .retry,
                        onSeeAll: _openNotifications,
                      ),
                      const SizedBox(height: AppSpacing.x4),
                    ],
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

/// Connection badge showing live telemetry status with semantic dot.
class _DashboardConnectionBadge extends StatelessWidget {
  const _DashboardConnectionBadge({required this.connection});

  final LiveConnection connection;

  @override
  Widget build(BuildContext context) {
    final (label, dotColor) = switch (connection) {
      LiveConnection.live => ('Live', AppColors.success),
      LiveConnection.connecting => ('Connecting', AppColors.warning),
      LiveConnection.offline => ('Offline', AppColors.error),
    };

    return Container(
      key: const Key('dashboard-connection'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2 + 2,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.x1 + 2),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
