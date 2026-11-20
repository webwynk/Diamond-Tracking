import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../../duty/domain/duty_day.dart';
import '../application/route_providers.dart';
import 'day_route_view.dart';

/// A list of duty days, newest first. The employee's History tab shows their
/// own; the admin opens it for any user.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({
    required this.dayRoute,
    super.key,
    this.userId,
    this.title = 'History',
  });

  /// The page to open for a day, given its id.
  final String Function(int dayId) dayRoute;

  /// Whose days. Null: the signed-in user.
  final String? userId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthStatus status = ref.watch(authStatusProvider);
    final String? who = userId ?? (status is SignedIn ? status.userId : null);
    if (who == null) return const SizedBox.shrink();
    final AsyncValue<List<DutyDay>> days = ref.watch(historyProvider(who));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: days.when(
        skipLoadingOnRefresh: true,
        data: (List<DutyDay> list) => list.isEmpty
            ? const Padding(
                padding: AppSpacing.screen,
                child: AppEmptyState(
                  title: 'No days yet',
                  description: 'Days appear here after the first duty.',
                  icon: Icons.calendar_month_rounded,
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(historyProvider(who).future),
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int i) =>
                      _DayTile(day: list[i], onTap: dayRoute),
                ),
              ),
        error: (_, _) =>
            AppErrorView(onRetry: () => ref.invalidate(historyProvider(who))),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day, required this.onTap});

  final DutyDay day;
  final String Function(int dayId) onTap;

  @override
  Widget build(BuildContext context) {
    final List<String> details = <String>[
      day.status.label,
      if (day.dutyOnAt case final DateTime on)
        '${IstFormat.time(on)} to '
            '${day.dutyOffAt == null ? 'now' : IstFormat.time(day.dutyOffAt!)}',
      if (day.distanceM case final int m) formatKm(m),
    ];
    final bool hasRoute = day.dutyOnAt != null;
    return ListTile(
      title: Text(IstFormat.date(day.day)),
      subtitle: Text(details.join(' · ')),
      leading: Icon(
        hasRoute ? Icons.route_rounded : Icons.event_note_rounded,
        color: day.status == DayStatus.absent
            ? AppColors.error
            : AppColors.primary600,
      ),
      trailing: hasRoute ? const Icon(Icons.chevron_right_rounded) : null,
      onTap: hasRoute ? () => context.push(onTap(day.id)) : null,
    );
  }
}
