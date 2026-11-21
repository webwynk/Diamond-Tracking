import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/app_banner.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../notifications/application/notifications_providers.dart';
import '../../notifications/domain/app_notification.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../users/application/users_providers.dart';
import '../../users/domain/profile.dart';
import '../../users/presentation/account_button.dart';
import '../application/requests_providers.dart';
import '../domain/app_request.dart';
import 'request_widgets.dart';

/// The admin's Requests tab: waiting requests first, then all recent ones.
class AdminRequestsPage extends ConsumerWidget {
  const AdminRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A new notification usually means a new request: reload the lists.
    ref.listen<AsyncValue<List<AppNotification>>>(notificationsProvider, (
      AsyncValue<List<AppNotification>>? before,
      AsyncValue<List<AppNotification>> now,
    ) {
      final int? was = before?.value?.firstOrNull?.id;
      final int? latest = now.value?.firstOrNull?.id;
      if (was != null && latest != was) {
        ref.invalidate(adminRequestsProvider);
      }
    });
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Requests'),
          actions: const <Widget>[NotificationBell(), AccountButton()],
          bottom: const TabBar(
            tabs: <Tab>[
              Tab(text: 'Waiting'),
              Tab(text: 'All'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _RequestList(pendingOnly: true),
            _RequestList(pendingOnly: false),
          ],
        ),
      ),
    );
  }
}

class _RequestList extends ConsumerWidget {
  const _RequestList({required this.pendingOnly});

  final bool pendingOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppRequest>> list = ref.watch(
      adminRequestsProvider(pendingOnly),
    );
    final AsyncValue<List<Profile>> users = ref.watch(usersListProvider);
    final Map<String, String> names = <String, String>{
      for (final Profile p in users.value ?? <Profile>[]) p.id: p.fullName,
    };
    // Names come from the users list; when it failed, say so (L71).
    final bool namesFailed = users.hasError && !users.hasValue;
    final int limit = ref.watch(adminRequestsLimitProvider(pendingOnly));
    return list.when(
      skipLoadingOnRefresh: true,
      data: (List<AppRequest> items) => RefreshIndicator(
        onRefresh: () => ref.refresh(adminRequestsProvider(pendingOnly).future),
        child: items.isEmpty
            ? ListView(
                children: <Widget>[
                  Padding(
                    padding: AppSpacing.screen,
                    child: AppEmptyState(
                      title: pendingOnly
                          ? 'Nothing waiting'
                          : 'No requests yet',
                      description: pendingOnly
                          ? 'New attendance, leave and short-duty requests '
                                'show here.'
                          : 'Requests show here once employees send them.',
                      icon: Icons.inbox_rounded,
                    ),
                  ),
                ],
              )
            : ListView(
                children: <Widget>[
                  if (namesFailed)
                    AppBanner(
                      icon: Icons.person_off_rounded,
                      backgroundColor: AppColors.warningBg,
                      iconColor: AppColors.warning,
                      title: 'Names could not load',
                      actionLabel: 'Retry',
                      onAction: () => ref.invalidate(usersListProvider),
                      isActionPill: true,
                    ),
                  for (final AppRequest r in items) ...<Widget>[
                    RequestTile(
                      request: r,
                      personName:
                          names[r.userId] ??
                          (namesFailed || !users.hasValue ? '…' : 'Unknown'),
                      onTap: () => context.push(Routes.adminRequest(r.id)),
                    ),
                    const Divider(height: 1),
                  ],
                  if (items.length >= limit)
                    ShowMoreButton(
                      onPressed: () => ref
                          .read(
                            adminRequestsLimitProvider(pendingOnly).notifier,
                          )
                          .more(),
                    ),
                ],
              ),
      ),
      error: (_, _) => AppErrorView(
        onRetry: () => ref.invalidate(adminRequestsProvider(pendingOnly)),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
