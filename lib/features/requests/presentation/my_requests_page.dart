import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../application/requests_providers.dart';
import '../domain/app_request.dart';
import 'request_widgets.dart';

/// The employee's requests, with buttons for new ones.
class MyRequestsPage extends ConsumerWidget {
  const MyRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppRequest>> list = ref.watch(myRequestsProvider);
    final List<AppRequest> mine = (list.value ?? const <AppRequest>[])
        .where((AppRequest r) => r.kind != RequestKind.shortDuty)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('My requests')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myRequestsProvider.future),
        child: ListView(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(AppSpacing.x4),
              child: NewRequestButtons(),
            ),
            const Divider(height: 1),
            if (list.hasError && !list.hasValue)
              AppErrorView(onRetry: () => ref.invalidate(myRequestsProvider))
            else if (!list.hasValue)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.x8),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (mine.isEmpty)
              const Padding(
                padding: AppSpacing.screen,
                child: AppEmptyState(
                  title: 'No requests yet',
                  description: 'Requests you send show here with the decision.',
                  icon: Icons.inbox_rounded,
                ),
              )
            else
              for (final AppRequest r in mine) ...<Widget>[
                RequestTile(
                  request: r,
                  onTap: () => context.push(Routes.userRequest(r.id)),
                ),
                const Divider(height: 1),
              ],
          ],
        ),
      ),
    );
  }
}

/// "Request attendance" and "Leave request".
class NewRequestButtons extends StatelessWidget {
  const NewRequestButtons({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => context.push(Routes.userRequestAttendance),
          icon: const Icon(Icons.event_available_rounded),
          label: const Text('Request attendance'),
        ),
      ),
      const SizedBox(width: AppSpacing.x3),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => context.push(Routes.userRequestLeave),
          icon: const Icon(Icons.beach_access_rounded),
          label: const Text('Leave request'),
        ),
      ),
    ],
  );
}
