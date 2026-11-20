import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';

import '../../../core/rules/duty_rules.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/widgets/app_banner.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../requests/presentation/my_requests_page.dart';
import '../../tracking/application/tracker_control.dart';
import '../../tracking/application/tracker_providers.dart';
import '../../tracking/presentation/tracking_setup_sheet.dart';
import '../../tracking/service/battery_alerts.dart';
import '../../visits/application/visits_providers.dart';
import '../../visits/domain/visit.dart';
import '../../visits/presentation/visit_widgets.dart';
import '../application/duty_providers.dart';
import '../domain/duty_day.dart';
import '../domain/duty_failure.dart';
import '../domain/duty_home.dart';

/// The employee's home: duty on, duty off, and today's status.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<int>? _battery;
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(dutyHomeProvider.notifier).refresh(),
    );
    _battery = ref
        .read(trackerControlProvider)
        .batteryWarnings
        .listen(_showBatteryWarning);
    // Elapsed time, and the 5:00 / 8:30 window, move on their own.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_battery?.cancel());
    _ticker?.cancel();
    super.dispose();
  }

  DutyHomeController get _controller => ref.read(dutyHomeProvider.notifier);

  Future<void> _dutyOn() async {
    final List<TrackerRequirement> missing = await _controller
        .missingRequirements();
    if (!mounted) return;
    if (missing.any((TrackerRequirement r) => r.required)) {
      if (!await showTrackingSetup(context)) return;
    } else if (missing.contains(TrackerRequirement.batteryOptimization)) {
      // Asked each time, but not required.
      await ref
          .read(trackerControlProvider)
          .request(TrackerRequirement.batteryOptimization);
    }
    if (!mounted) return;
    setState(() => _busy = true);
    String? problem;
    try {
      await _controller.dutyOn();
    } on DutyException catch (e) {
      problem = e.failure.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (problem != null) {
      await _showProblem(problem);
    } else {
      _snack('Duty on. Your route is being recorded.');
    }
  }

  Future<void> _dutyOff(DutyDay day) async {
    final Duration worked = ref
        .read(serverClockProvider)
        .now()
        .difference(day.dutyOnAt!);
    final bool short = worked < DutyRules.minimumDuty;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Duty off?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('You have worked ${IstFormat.duration(worked)} today.'),
            const SizedBox(height: AppSpacing.x2),
            const Text(
              'After duty off you cannot do duty on again today, and your '
              'route stops being recorded.',
            ),
            if (short) ...<Widget>[
              const SizedBox(height: AppSpacing.x3),
              Text(
                'This is less than 10 hours. The day will not count for '
                'attendance unless the admin approves it.',
                style: AppTypography.body.copyWith(
                  color: AppColors.warningText,
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Duty off'),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    setState(() => _busy = true);
    DutyOffOutcome? outcome;
    String? problem;
    try {
      outcome = await _controller.dutyOff();
    } on DutyException catch (e) {
      problem = e.failure.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (problem != null) {
      await _showProblem(problem);
    } else if (outcome!.isShort) {
      await _showShortDay(outcome);
    } else if (outcome.savedOffline) {
      _snack('No internet. Duty off is saved and will be sent by itself.');
    } else {
      _snack('Duty off done. Thank you.');
    }
  }

  Future<void> _showShortDay(DutyOffOutcome outcome) => showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      icon: const Icon(Icons.info_outline_rounded, color: AppColors.warning),
      title: const Text('Not eligible for attendance'),
      content: Text(
        'You worked ${IstFormat.duration(outcome.worked)}, less than 10 '
        'hours. The admin will decide: present, half day or absent.'
        '${outcome.savedOffline ? '\n\nNo internet: the duty off is saved and will be sent by itself.' : ''}',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  Future<void> _showProblem(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBatteryWarning(int level) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: Icon(
          Icons.battery_alert_rounded,
          color: level <= 10 ? AppColors.error : AppColors.warning,
        ),
        title: Text('Battery $level%'),
        content: Text(batteryMessage(level)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DutyHome> home = ref.watch(dutyHomeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: const <Widget>[NotificationBell()],
      ),
      body: home.when(
        skipLoadingOnRefresh: true,
        data: (DutyHome value) => RefreshIndicator(
          onRefresh: _controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            children: <Widget>[
              if (!value.serverReachable) ...<Widget>[
                AppBanner.offline(),
                const SizedBox(height: AppSpacing.x3),
              ],
              if (value.trackingProblem case final String problem) ...<Widget>[
                AppBanner(
                  icon: Icons.location_disabled_rounded,
                  backgroundColor: AppColors.errorBg,
                  iconColor: AppColors.error,
                  title: 'Route is not being recorded',
                  subtitle: problem,
                  actionLabel: 'Try again',
                  onAction: _controller.refresh,
                  isActionPill: true,
                ),
                const SizedBox(height: AppSpacing.x3),
              ],
              _DutyCard(
                home: value,
                now: ref.read(serverClockProvider).now(),
                busy: _busy,
                onDutyOn: _dutyOn,
                onDutyOff: _dutyOff,
              ),
              if (value.today case final DutyDay day
                  when day.dutyOnAt != null) ...<Widget>[
                const SizedBox(height: AppSpacing.x4),
                _VisitsCard(day: day),
              ],
              const SizedBox(height: AppSpacing.x4),
              const _RequestsCard(),
            ],
          ),
        ),
        error: (Object e, _) => AppErrorView(
          onRetry: () => ref.invalidate(dutyHomeProvider),
          message: mapDutyError(e).message,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _DutyCard extends StatelessWidget {
  const _DutyCard({
    required this.home,
    required this.now,
    required this.busy,
    required this.onDutyOn,
    required this.onDutyOff,
  });

  final DutyHome home;
  final DateTime now;
  final bool busy;
  final VoidCallback onDutyOn;
  final void Function(DutyDay day) onDutyOff;

  @override
  Widget build(BuildContext context) {
    final DutyDay? day = home.today;
    final List<Widget> children = switch (home.phaseAt(now)) {
      DutyPhase.beforeWindow => <Widget>[
        const _Heading(icon: Icons.schedule_rounded, title: 'Not on duty'),
        const _Line('Duty on opens at 5:00 AM.'),
        const SizedBox(height: AppSpacing.x4),
        const AppButton(
          label: 'Duty on',
          isFullWidth: true,
          onPressed: null,
          disabledReason: 'Duty on opens at 5:00 AM',
        ),
      ],
      DutyPhase.canDutyOn => <Widget>[
        const _Heading(icon: Icons.wb_sunny_rounded, title: 'Ready to start'),
        const _Line('Duty on is open until 8:30 AM.'),
        const SizedBox(height: AppSpacing.x4),
        AppButton(
          label: 'Duty on',
          isFullWidth: true,
          isLoading: busy,
          loadingLabel: 'Starting…',
          icon: const Icon(Icons.play_arrow_rounded),
          onPressed: onDutyOn,
        ),
      ],
      DutyPhase.allowedByAdmin => <Widget>[
        const _Heading(icon: Icons.verified_rounded, title: 'Ready to start'),
        const _Line(
          'The admin allowed you to do duty on today. It works once, until '
          '11:00 PM.',
        ),
        const SizedBox(height: AppSpacing.x4),
        AppButton(
          label: 'Duty on',
          isFullWidth: true,
          isLoading: busy,
          loadingLabel: 'Starting…',
          icon: const Icon(Icons.play_arrow_rounded),
          onPressed: onDutyOn,
        ),
      ],
      DutyPhase.windowClosed => <Widget>[
        const _Heading(
          icon: Icons.event_busy_rounded,
          title: 'Duty on is closed for today',
        ),
        const _Line(
          'Duty on is allowed from 5:00 AM to 8:30 AM. If you worked today, '
          'use Request attendance below.',
        ),
      ],
      DutyPhase.onDuty => <Widget>[
        const _Heading(
          icon: Icons.directions_walk_rounded,
          title: 'On duty',
          color: AppColors.success,
        ),
        _Line('Since ${IstFormat.time(day!.dutyOnAt!)}'),
        const SizedBox(height: AppSpacing.x2),
        Text(
          IstFormat.duration(now.difference(day.dutyOnAt!)),
          style: AppTypography.display,
        ),
        const _Line('Duty ends by itself at 11:00 PM.'),
        const SizedBox(height: AppSpacing.x4),
        AppButton(
          label: 'Duty off',
          variant: AppButtonVariant.destructive,
          isFullWidth: true,
          isLoading: busy,
          loadingLabel: 'Ending…',
          icon: const Icon(Icons.stop_rounded),
          onPressed: () => onDutyOff(day),
        ),
      ],
      DutyPhase.offSaved => <Widget>[
        const _Heading(
          icon: Icons.cloud_upload_rounded,
          title: 'Duty off saved',
        ),
        _Line(
          'Duty off at ${IstFormat.time(home.session!.offAt!)}. It will be '
          'sent by itself when the internet is back.',
        ),
      ],
      DutyPhase.ended => <Widget>[
        _Heading(
          icon: Icons.check_circle_rounded,
          title: day!.status.label,
          color: day.status == DayStatus.absent
              ? AppColors.error
              : AppColors.primary600,
        ),
        if (day.dutyOnAt case final DateTime on)
          _Line(
            'Duty ${IstFormat.time(on)} to '
            '${IstFormat.time(day.dutyOffAt ?? home.session?.offAt ?? now)}'
            '${day.workedMinutes == null ? '' : ' (${IstFormat.duration(Duration(minutes: day.workedMinutes!))})'}',
          ),
        if (day.autoEnded) const _Line('Ended by itself at 11:00 PM.'),
        if (day.status == DayStatus.pending)
          const _Line(
            'Less than 10 hours, so not counted for attendance yet. The '
            'admin will decide.',
          ),
      ],
      DutyPhase.onLeave => <Widget>[
        const _Heading(icon: Icons.beach_access_rounded, title: 'On leave'),
        const _Line('You are on leave today.'),
      ],
    };
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.icon,
    required this.title,
    this.color = AppColors.primary600,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.x2),
    child: Row(
      children: <Widget>[
        Icon(icon, color: color),
        const SizedBox(width: AppSpacing.x2),
        Expanded(child: Text(title, style: AppTypography.h3)),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      text,
      style: AppTypography.body.copyWith(color: AppColors.textSecondary),
    ),
  );
}

/// Attendance and leave requests.
class _RequestsCard extends StatelessWidget {
  const _RequestsCard();

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: AppSpacing.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text('Requests', style: AppTypography.title),
              ),
              TextButton(
                onPressed: () => context.push(Routes.userRequests),
                child: const Text('My requests'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          const NewRequestButtons(),
        ],
      ),
    ),
  );
}

/// Today's dealer visits, with Add visit while on duty.
class _VisitsCard extends ConsumerWidget {
  const _VisitsCard({required this.day});

  final DutyDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Visit>> visits = ref.watch(dayVisitsProvider(day.id));
    final bool onDuty = day.status == DayStatus.onDuty;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Visits today', style: AppTypography.title),
            const SizedBox(height: AppSpacing.x2),
            ...visits.when(
              skipLoadingOnRefresh: true,
              data: (List<Visit> list) => list.isEmpty
                  ? <Widget>[
                      Text(
                        onDuty
                            ? 'No visits yet. Add one at each dealer, with a '
                                  'photo.'
                            : 'No visits today.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ]
                  : <Widget>[for (final Visit v in list) VisitTile(visit: v)],
              error: (_, _) => <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(child: Text('Visits could not be loaded.')),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(dayVisitsProvider(day.id)),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ],
              loading: () => const <Widget>[
                Center(child: CircularProgressIndicator()),
              ],
            ),
            if (onDuty) ...<Widget>[
              const SizedBox(height: AppSpacing.x3),
              AppButton(
                label: 'Add visit',
                isFullWidth: true,
                icon: const Icon(Icons.add_a_photo_rounded),
                onPressed: () => context.push(Routes.userAddVisit(day.id)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
