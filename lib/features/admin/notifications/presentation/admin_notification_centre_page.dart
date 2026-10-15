import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../dashboard/presentation/widgets/admin_bottom_navigation.dart';
import 'controllers/admin_notification_controller.dart';
import 'widgets/admin_notification_feed.dart';
import 'widgets/admin_notification_filter_chips.dart';
import 'widgets/admin_notification_ticker.dart';
import 'widgets/admin_notification_top_bar.dart';

/// Screen 21 — Notification Centre (Admin).
///
/// Complete in-app operational alert and notification hub:
/// - 56 dp white app bar with back chevron, title "Notifications", unread count pill badge, and "Mark all read" button
/// - Operational telemetry ticker ("SYNC ENGINE: ACTIVE", Fleet latency 1.2s)
/// - Horizontally scrolling 32 dp category filter chips ("Unread [count]", "All", "Duty", "Alerts", "Visits")
/// - Notification stream rows (76 dp tall, 16 dp padding) with 40 dp circular tinted badges,
///   unread styling (#E8F3F8 background with 4 dp #016893 left accent bar), title, subtitle, and timestamp
/// - Sticky cadence separator ("EARLIER TODAY")
/// - Operational footer note ("END OF EVENT LOG", verified badge, 90-day retention note)
/// - Persistent admin bottom navigation bar
class AdminNotificationCentrePage extends ConsumerWidget {
  const AdminNotificationCentrePage({
    super.key,
    this.onBack,
    this.onNavigateHome,
    this.onNavigateMap,
    this.onNavigateTeam,
    this.onNavigatePlaces,
    this.onNavigateReports,
  });

  final VoidCallback? onBack;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateMap;
  final VoidCallback? onNavigateTeam;
  final VoidCallback? onNavigatePlaces;
  final VoidCallback? onNavigateReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminNotificationControllerProvider);
    final notifier = ref.read(adminNotificationControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AdminNotificationTopBar(
        unreadCount: state.unreadCount,
        onBack: onBack ?? () => Navigator.of(context).maybePop(),
        onMarkAllRead: () {
          notifier.markAllAsRead();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications marked as read.'),
              duration: Duration(seconds: 1),
            ),
          );
        },
      ),
      body: Column(
        children: <Widget>[
          // 1. Operational Telemetry Ticker
          const AdminNotificationTicker(),

          // 2. Horizontal Filter Chip Row
          AdminNotificationFilterChips(
            selectedFilter: state.selectedFilter,
            unreadCount: state.unreadCount,
            onSelectFilter: (filter) => notifier.setFilter(filter),
          ),

          // 3. Notification Stream Feed
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: AdminNotificationFeed(
                items: state.filteredNotifications,
                onTapItem: (id) => notifier.markAsRead(id),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AdminBottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              if (onNavigateHome != null) {
                onNavigateHome!();
              } else {
                Navigator.of(context).maybePop();
              }
              break;
            case 1:
              onNavigateMap?.call();
              break;
            case 2:
              onNavigateTeam?.call();
              break;
            case 3:
              onNavigatePlaces?.call();
              break;
            case 4:
              onNavigateReports?.call();
              break;
          }
        },
      ),
    );
  }
}
