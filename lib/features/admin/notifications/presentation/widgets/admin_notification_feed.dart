import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/app_empty_state.dart';
import '../admin_notification_presenter.dart';
import '../controllers/admin_notification_state.dart';
import 'admin_notification_tile.dart';

/// The notification list: rows under the heading of their IST day ("Today",
/// "Yesterday", "Sat, 11 Oct"), then a way to load older ones.
class AdminNotificationFeed extends StatelessWidget {
  const AdminNotificationFeed({
    super.key,
    required this.rows,
    required this.filter,
    required this.now,
    required this.onTapRow,
    required this.hasMore,
    required this.isLoadingMore,
    required this.loadMoreFailed,
    required this.onLoadMore,
    this.hasEmployeeQuery = false,
  });

  final List<AdminNotificationRow> rows;
  final AdminNotificationFilter filter;

  /// Only decides which day is "Today" in the headings.
  final DateTime now;
  final ValueChanged<AdminNotificationRow> onTapRow;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;
  final VoidCallback onLoadMore;
  final bool hasEmployeeQuery;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return _empty();

    final children = <Widget>[];
    String? heading;
    for (final row in rows) {
      final day = AdminNotificationPresenter.dayHeading(
        row.notification.createdAt,
        now,
      );
      if (day != heading) {
        heading = day;
        children.add(_dayHeader(day));
      }
      children.add(
        AdminNotificationTile(item: row, onTap: () => onTapRow(row)),
      );
    }
    children.add(_footer());
    return Column(children: children);
  }

  Widget _dayHeader(String day) {
    return Container(
      key: Key('notif-day-$day'),
      height: 32,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.neutral50,
        border: Border(
          top: BorderSide(color: AppColors.neutral200, width: 1),
          bottom: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      alignment: Alignment.centerLeft,
      child: Text(
        day.toUpperCase(),
        style: AppTypography.overline.copyWith(
          color: AppColors.neutral500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _footer() {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.x4),
        child: Center(
          child: SizedBox(
            key: Key('notif-loading-more'),
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.x2),
        child: Column(
          children: <Widget>[
            Text(
              "Couldn't load older notifications.",
              key: const Key('notif-load-more-failed'),
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            TextButton(onPressed: onLoadMore, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.x2),
        child: TextButton(
          key: const Key('btn-notif-load-more'),
          onPressed: onLoadMore,
          child: const Text('Load older notifications'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Center(
        child: Text(
          'No older notifications',
          key: const Key('notif-end'),
          style: AppTypography.caption.copyWith(color: AppColors.neutral400),
        ),
      ),
    );
  }

  Widget _empty() {
    if (hasEmployeeQuery) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.x8),
        child: AppEmptyState(
          icon: Icons.person_search_outlined,
          title: 'No notifications for that employee',
          description: 'Check the name or code, or change the filter.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: switch (filter) {
        AdminNotificationFilter.unread => AppEmptyState.noNotifications(),
        AdminNotificationFilter.all => const AppEmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'No notifications yet',
          description: 'Duty events and alerts will appear here.',
        ),
        AdminNotificationFilter.duty => const AppEmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'No duty notifications',
          description: 'Duty starts and ends will appear here.',
        ),
        AdminNotificationFilter.alerts => const AppEmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'No alerts',
          description: 'Tracking problems and warnings will appear here.',
        ),
      },
    );
  }
}
