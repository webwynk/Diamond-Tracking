import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_banner.dart';
import '../../duty/domain/duty_day.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../requests/application/requests_providers.dart';
import '../../requests/domain/app_request.dart';
import '../../routes/application/route_providers.dart';
import '../../users/presentation/account_button.dart';

/// How often the dashboard reloads by itself (L85).
const Duration dashboardRefreshEvery = Duration(minutes: 2);

/// Today at a glance: who is on duty and what is waiting for a decision.
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboardPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(dashboardRefreshEvery, (_) => _reload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    ref
      ..invalidate(todayDaysProvider)
      ..invalidate(adminRequestsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<DutyDay>> daysValue = ref.watch(todayDaysProvider);
    final AsyncValue<List<AppRequest>> waitingValue = ref.watch(
      adminRequestsProvider(true),
    );
    final List<DutyDay>? days = daysValue.value;
    final List<AppRequest>? waiting = waitingValue.value;
    final bool failed =
        (daysValue.hasError && !daysValue.hasValue) ||
        (waitingValue.hasError && !waitingValue.hasValue);
    final int limit = ref.watch(adminRequestsLimitProvider(true));
    int count(DayStatus s) =>
        days?.where((DutyDay d) => d.status == s).length ?? 0;
    String n(int? v) => v == null ? '–' : '$v';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const <Widget>[NotificationBell(), AccountButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: <Widget>[
            if (failed) ...<Widget>[
              AppBanner(
                icon: Icons.cloud_off_rounded,
                backgroundColor: AppColors.errorBg,
                iconColor: AppColors.error,
                title: 'Could not load today',
                subtitle: 'Check the internet.',
                actionLabel: 'Retry',
                onAction: _reload,
                isActionPill: true,
              ),
              const SizedBox(height: AppSpacing.x3),
            ],
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
                  value: waiting != null && waiting.length >= limit
                      ? '${waiting.length}+'
                      : n(waiting?.length),
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
