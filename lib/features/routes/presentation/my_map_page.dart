import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../duty/domain/duty_day.dart';
import '../application/route_providers.dart';
import 'day_route_view.dart';

/// The employee's Map tab: today's route.
class MyMapPage extends ConsumerWidget {
  const MyMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DutyDay?> today = ref.watch(myTodayProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My map'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(myTodayProvider);
              final int? id = today.value?.id;
              if (id != null) ref.invalidate(dayViewProvider(id));
            },
          ),
        ],
      ),
      body: today.when(
        data: (DutyDay? day) => day == null || day.dutyOnAt == null
            ? const Padding(
                padding: AppSpacing.screen,
                child: AppEmptyState(
                  title: 'No route today',
                  description: 'Your route shows here after duty on.',
                  icon: Icons.map_rounded,
                ),
              )
            : DayRouteView(dayId: day.id),
        error: (_, _) =>
            AppErrorView(onRetry: () => ref.invalidate(myTodayProvider)),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
