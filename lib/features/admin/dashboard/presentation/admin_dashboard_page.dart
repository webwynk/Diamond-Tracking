import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../employees/presentation/admin_employee_list_page.dart';
import '../../map/presentation/admin_live_map_page.dart';
import '../../notifications/presentation/admin_notification_centre_page.dart';
import 'controllers/admin_dashboard_controller.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_map_preview_card.dart';
import 'widgets/admin_recent_activity_card.dart';
import 'widgets/admin_stat_card.dart';

/// Screen 14 — Admin Home / Dashboard
///
/// Serves as the central command console for office administrators, answering
/// "Who is working right now?" in under two seconds.
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({
    super.key,
    this.onNavigateToMap,
    this.onNavigateToTeam,
    this.onNavigateToNotifications,
  });

  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToTeam;
  final VoidCallback? onNavigateToNotifications;

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _selectedNavIndex = 0;

  void _handleBroadcastAlert() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.campaign_rounded,
              color: AppColors.primary600,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.x2),
            Text(
              'Broadcast Alert',
              style: AppTypography.title.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Send an urgent operational broadcast to all 112 on-duty field officers across Maharashtra regions.',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.mdAll,
              ),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              AppSnackbar.show(
                context,
                message: 'Broadcast notification queued for delivery.',
              );
            },
            child: Text(
              'Send Broadcast',
              style: AppTypography.label.copyWith(
                color: AppColors.neutral0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleExportDayLog() {
    AppSnackbar.show(
      context,
      message: 'Exporting attendance & telemetry day log as CSV...',
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(adminDashboardControllerProvider);
    final dashboardNotifier =
        ref.read(adminDashboardControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.primary600,
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // App Title & Role Subtitle
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Diamond Agritech',
                        style: AppTypography.title.copyWith(
                          color: AppColors.neutral0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Admin • Home',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral0.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),

                  // Actions: Refresh + Bell with Badge + Avatar
                  Row(
                    children: [
                      IconButton(
                        key: const Key('admin-refresh-btn'),
                        icon: const Icon(
                          Icons.refresh_rounded,
                          size: 22,
                          color: AppColors.neutral0,
                        ),
                        tooltip: 'Refresh Data',
                        onPressed: () async {
                          await dashboardNotifier.refreshDashboard();
                          if (context.mounted) {
                            AppSnackbar.show(
                              context,
                              message: 'Dashboard telemetry refreshed.',
                            );
                          }
                        },
                      ),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            key: const Key('admin-notifications-btn'),
                            icon: const Icon(
                              Icons.notifications_none_rounded,
                              size: 24,
                              color: AppColors.neutral0,
                            ),
                            tooltip: 'Notifications',
                            onPressed: widget.onNavigateToNotifications ??
                                () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (ctx) =>
                                          const AdminNotificationCentrePage(),
                                    ),
                                  );
                                },
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 16),
                              height: 16,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                dashboardState.unreadNotificationsCount.toString(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.neutral0,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary500,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.person_rounded,
                          size: 18,
                          color: AppColors.neutral0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary600,
          onRefresh: () => dashboardNotifier.refreshDashboard(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Operational Timestamp Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: AppColors.primary600,
                          ),
                          const SizedBox(width: AppSpacing.x1),
                          Expanded(
                            child: Text(
                              'Sunday, 12 October 2026 · 2:48 PM',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: AppRadius.fullAll,
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'TELEMETRY LIVE',
                            style: AppTypography.overline.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
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
                        value: dashboardState.onDutyCount.toString(),
                        label: 'ON DUTY',
                        icon: Icons.person,
                        badgeColor: AppColors.successBg,
                        iconColor: AppColors.success,
                        trailingIcon: Icons.north_east_rounded,
                        onTap: widget.onNavigateToTeam,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    // Card 2: OFF DUTY
                    Expanded(
                      child: AdminStatCard(
                        value: dashboardState.offDutyCount.toString(),
                        label: 'OFF DUTY',
                        icon: Icons.person_off_rounded,
                        badgeColor: AppColors.neutral100,
                        iconColor: AppColors.textDisabled,
                        trailingIcon: Icons.horizontal_rule_rounded,
                        onTap: widget.onNavigateToTeam,
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
                        value: dashboardState.noUpdateCount.toString(),
                        label: 'NO UPDATE',
                        icon: Icons.signal_wifi_off_rounded,
                        badgeColor: AppColors.warningBg,
                        iconColor: AppColors.warning,
                        borderColor: AppColors.warning,
                        backgroundColor:
                            AppColors.warningBg.withValues(alpha: 0.12),
                        labelColor: AppColors.warningText,
                        showPingDot: true,
                        pingColor: AppColors.warning,
                        onTap: widget.onNavigateToTeam,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    // Card 4: NEEDS CHECK (Suspect Alert)
                    Expanded(
                      child: AdminStatCard(
                        value: dashboardState.needsCheckCount.toString(),
                        label: 'NEEDS CHECK',
                        icon: Icons.warning_amber_rounded,
                        badgeColor: AppColors.errorBg,
                        iconColor: AppColors.error,
                        borderColor: AppColors.error,
                        backgroundColor:
                            AppColors.errorBg.withValues(alpha: 0.12),
                        labelColor: AppColors.error,
                        showPingDot: true,
                        pingColor: AppColors.error,
                        onTap: widget.onNavigateToTeam,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x4),

                // 3. Live Map Preview Card
                AdminMapPreviewCard(
                  onViewMap: () {
                    if (widget.onNavigateToMap != null) {
                      widget.onNavigateToMap!();
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminLiveMapPage(),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.x4),

                // 4. Recent Activity Feed Card
                AdminRecentActivityCard(
                  activities: dashboardState.activities,
                  onSeeAll: () {
                    if (widget.onNavigateToNotifications != null) {
                      widget.onNavigateToNotifications!();
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.x4),

                // 5. Utilitarian Quick Field Action Toolbar
                Row(
                  children: [
                    // Button 1: Broadcast Alert
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          key: const Key('btn-broadcast-alert'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary600,
                            foregroundColor: AppColors.neutral0,
                            elevation: 0,
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.mdAll,
                            ),
                          ),
                          onPressed: _handleBroadcastAlert,
                          icon: const Icon(Icons.campaign_rounded, size: 20),
                          label: Text(
                            'Broadcast Alert',
                            style: AppTypography.label.copyWith(
                              color: AppColors.neutral0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    // Button 2: Export Day Log
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          key: const Key('btn-export-day-log'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary600,
                            backgroundColor: AppColors.surface,
                            side: const BorderSide(
                              color: AppColors.primary600,
                              width: 1,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.mdAll,
                            ),
                          ),
                          onPressed: _handleExportDayLog,
                          icon: const Icon(Icons.download_rounded, size: 20),
                          label: Text(
                            'Export Day Log',
                            style: AppTypography.label.copyWith(
                              color: AppColors.primary600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x4),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AdminBottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (index) {
          setState(() => _selectedNavIndex = index);
          if (index == 1) {
            if (widget.onNavigateToMap != null) {
              widget.onNavigateToMap!();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminLiveMapPage(),
                ),
              );
            }
          } else if (index == 2) {
            if (widget.onNavigateToTeam != null) {
              widget.onNavigateToTeam!();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminEmployeeListPage(),
                ),
              );
            }
          }
        },
      ),
    );
  }
}
