import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/phone_clock.dart';
import '../../../../domain/entities/admin_notification.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../../shared/widgets/skeletons/widgets/notification_list_skeleton.dart';
import '../../map/presentation/controllers/admin_live_map_controller.dart';
import '../../route_view/presentation/admin_route_view_page.dart';
import '../../shell/admin_tab.dart';
import 'admin_notification_presenter.dart';
import 'controllers/admin_notification_controller.dart';
import 'controllers/admin_notification_state.dart';
import 'widgets/admin_notification_feed.dart';
import 'widgets/admin_notification_filter_chips.dart';

/// Screen 21 — Notification Centre (Admin), PRD F12.
///
/// Duty events and alerts (tracking broken, fake GPS, low battery) written by
/// the server, newest first under IST day headings. The number on the bell and
/// in the title is the server's unread count. Filters: unread, duty, alerts, and
/// an employee (name or code); older notifications load on request. Read state
/// is per admin. Tapping one marks it read and opens what it is about: the live
/// map on that employee for an alert while they are on duty, otherwise their
/// route for that day.
class AdminNotificationCentrePage extends ConsumerStatefulWidget {
  const AdminNotificationCentrePage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<AdminNotificationCentrePage> createState() =>
      _AdminNotificationCentrePageState();
}

class _AdminNotificationCentrePageState
    extends ConsumerState<AdminNotificationCentrePage> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(AdminNotificationRow row) {
    final notifier = ref.read(adminNotificationControllerProvider.notifier);
    final names = ref.read(adminNotificationControllerProvider).names;
    final n = row.notification;
    notifier.markRead(n.id);

    // Security alerts have no route or position to show: reading is enough.
    if (n.type == AdminNotificationType.accountLocked ||
        n.type == AdminNotificationType.failedLogin ||
        n.type == AdminNotificationType.newDeviceLogin) {
      return;
    }

    final onDuty = ref
        .read(adminLiveMapControllerProvider)
        .officers
        .any((officer) => officer.id == n.employeeId);
    if (n.type.isAlert && onDuty) {
      ref.read(liveMapFocusProvider.notifier).request(n.employeeId);
      ref.read(adminTabProvider.notifier).select(AdminTab.map);
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminRouteViewPage(
          employeeId: n.employeeId,
          employeeName: names[n.employeeId]?.name ?? 'Employee',
          dayId: AdminNotificationPresenter.istDayId(n.createdAt),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotificationControllerProvider);
    final notifier = ref.read(adminNotificationControllerProvider.notifier);

    ref.listen(
      adminNotificationControllerProvider.select((s) => s.actionError),
      (_, message) {
        if (message == null) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        notifier.clearActionError();
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        leading: AppTopBarLeading.back,
        leadingKey: const Key('btn-notif-back'),
        onLeadingPressed: widget.onBack,
        title: 'Notifications',
        titleTrailing: state.unreadCount > 0
            ? AppBadge.count(
                state.unreadCount,
                key: const Key('badge-unread-count-pill'),
                backgroundColor: AppColors.error,
              )
            : null,
        actions: <Widget>[
          TextButton(
            key: const Key('btn-mark-all-read'),
            onPressed: state.unreadCount > 0 ? notifier.markAllRead : null,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          AdminNotificationFilterChips(
            selectedFilter: state.selectedFilter,
            unreadCount: state.unreadCount,
            onSelectFilter: notifier.setFilter,
          ),
          _searchField(notifier),
          if (state.refreshFailed)
            Container(
              key: const Key('notif-refresh-failed'),
              width: double.infinity,
              color: AppColors.warningBg,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x2,
              ),
              child: Text(
                "Couldn't refresh. This may be out of date. Pull down to retry.",
                style: AppTypography.caption.copyWith(
                  color: AppColors.warningText,
                ),
              ),
            ),
          Expanded(child: _body(state, notifier)),
        ],
      ),
    );
  }

  Widget _searchField(AdminNotificationNotifier notifier) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      child: TextField(
        key: const Key('input-notif-employee'),
        controller: _search,
        onChanged: notifier.setEmployeeQuery,
        textInputAction: TextInputAction.search,
        style: AppTypography.body.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Employee name or ID',
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  key: const Key('btn-notif-clear-employee'),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Clear',
                  onPressed: () {
                    _search.clear();
                    notifier.setEmployeeQuery('');
                    setState(() {});
                  },
                ),
        ),
      ),
    );
  }

  Widget _body(
    AdminNotificationState state,
    AdminNotificationNotifier notifier,
  ) {
    if (state.errorMessage != null) {
      return AppErrorView(
        key: const Key('notif-error'),
        title: "Couldn't load the notifications",
        message: state.errorMessage!,
        onRetry: notifier.reload,
      );
    }
    if (state.isLoading) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: NotificationListSkeleton(),
      );
    }

    final rows = [
      for (final n in state.items)
        AdminNotificationPresenter.row(n, names: state.names),
    ];
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 300) notifier.loadMore();
          return false;
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: AdminNotificationFeed(
            rows: rows,
            filter: state.selectedFilter,
            now: ref.read(phoneClockProvider)(),
            onTapRow: _open,
            hasMore: state.hasMore,
            isLoadingMore: state.isLoadingMore,
            loadMoreFailed: state.loadMoreFailed,
            onLoadMore: notifier.loadMore,
            hasEmployeeQuery: state.hasActiveEmployeeQuery,
          ),
        ),
      ),
    );
  }
}
