import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../map/presentation/controllers/admin_live_map_controller.dart';
import '../../notifications/presentation/admin_notification_centre_page.dart';
import '../../notifications/presentation/controllers/admin_notification_controller.dart';
import '../../shell/admin_tab.dart';
import 'controllers/admin_dashboard_controller.dart';
import 'widgets/admin_map_preview_card.dart';
import 'widgets/admin_profile_sheet.dart';
import 'widgets/admin_recent_activity_card.dart';
import 'widgets/admin_stat_card.dart';

/// Screen 14 — Admin Home / Dashboard
///
/// Serves as the central command console for office administrators, answering
/// "Who is working right now?" in under two seconds.
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Today's date
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: AppColors.primary600,
                    ),
                    const SizedBox(width: AppSpacing.x1),
                    Expanded(
                      child: Text(
                        DateLabels.longDate(DateTime.now()),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),

                // 2. 2x2 Stat Cards Grid
                Row(
                  children: [
                    // Card 1: ON DUTY
                    Expanded(
                      child: AdminStatCard(
                        value: count(live.totalCount),
                        label: 'ON DUTY',
                        icon: Icons.person,
                        badgeColor: AppColors.successBg,
                        iconColor: AppColors.success,
                        trailingIcon: Icons.north_east_rounded,
                        onTap: () => _selectTab(AdminTab.team),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    // Card 2: OFF DUTY
                    Expanded(
                      child: AdminStatCard(
                        value: count(live.offDutyCount),
                        label: 'OFF DUTY',
                        icon: Icons.person_off_rounded,
                        badgeColor: AppColors.neutral100,
                        iconColor: AppColors.textDisabled,
                        trailingIcon: Icons.horizontal_rule_rounded,
                        onTap: () => _selectTab(AdminTab.team),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),

                Row(
                  children: [
                    // Card 3: NO UPDATE (Stale Warning)
                    Expanded(
                      child: AdminStatCard(
                        value: count(live.staleCount),
                        label: 'NO UPDATE',
                        icon: Icons.signal_wifi_off_rounded,
                        badgeColor: AppColors.warningBg,
                        iconColor: AppColors.warning,
                        borderColor: AppColors.warning,
                        backgroundColor: AppColors.warningBg.withValues(
                          alpha: 0.12,
                        ),
                        labelColor: AppColors.warningText,
                        showPingDot: true,
                        pingColor: AppColors.warning,
                        onTap: () => _selectTab(AdminTab.team),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    // Card 4: NEEDS CHECK (Suspect Alert)
                    Expanded(
                      child: AdminStatCard(
                        value: count(live.needsCheckCount),
                        label: 'NEEDS CHECK',
                        icon: Icons.warning_amber_rounded,
                        badgeColor: AppColors.errorBg,
                        iconColor: AppColors.error,
                        borderColor: AppColors.error,
                        backgroundColor: AppColors.errorBg.withValues(
                          alpha: 0.12,
                        ),
                        labelColor: AppColors.error,
                        showPingDot: true,
                        pingColor: AppColors.error,
                        onTap: () => _selectTab(AdminTab.team),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x4),

                // 3. Live Map Preview Card
                AdminMapPreviewCard(
                  officers: live.officers,
                  isLoading: live.isLoading,
                  errorMessage: live.errorMessage,
                  onViewMap: () => _selectTab(AdminTab.map),
                ),
                const SizedBox(height: AppSpacing.x4),

                // 4. Recent Activity Feed Card
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
        ),
      ),
    );
  }
}
