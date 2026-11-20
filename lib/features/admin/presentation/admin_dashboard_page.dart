import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../duty/domain/duty_day.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../requests/application/requests_providers.dart';
import '../../requests/domain/app_request.dart';
import '../../routes/application/route_providers.dart';
import '../../users/presentation/account_button.dart';

/// Today at a glance: who is on duty and what is waiting for a decision.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<DutyDay>? days = ref.watch(todayDaysProvider).value;
    final List<AppRequest>? waiting = ref
        .watch(adminRequestsProvider(true))
        .value;
    int count(DayStatus s) =>
        days?.where((DutyDay d) => d.status == s).length ?? 0;
    String n(int? v) => v == null ? '–' : '$v';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const <Widget>[NotificationBell(), AccountButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(todayDaysProvider)
            ..invalidate(adminRequestsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: <Widget>[
            const Text('Today', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.x3),
            Row(
              children: <Widget>[
                _Tile(
                  label: 'On duty',
                  value: n(days == null ? null : count(DayStatus.onDuty)),
                  color: AppColors.success,
                  onTap: () => context.go(Routes.adminLiveMap),
                ),
                const SizedBox(width: AppSpacing.x3),
                _Tile(
                  label: 'Finished',
                  value: n(
                    days == null
                        ? null
                        : count(DayStatus.present) +
                              count(DayStatus.halfDay) +
                              count(DayStatus.pending),
                  ),
                  color: AppColors.primary600,
                  onTap: () => context.go(Routes.adminLiveMap),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            Row(
              children: <Widget>[
                _Tile(
                  label: 'On leave',
                  value: n(days == null ? null : count(DayStatus.leave)),
                  color: AppColors.info,
                ),
                const SizedBox(width: AppSpacing.x3),
                _Tile(
                  label: 'Waiting requests',
                  value: n(waiting?.length),
                  color: (waiting?.isNotEmpty ?? false)
                      ? AppColors.warning
                      : AppColors.neutral500,
                  onTap: () => context.go(Routes.adminRequests),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(value, style: AppTypography.h1.copyWith(color: color)),
              const SizedBox(height: AppSpacing.x1),
              Text(
                label,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
