import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../../notifications/application/notifications_providers.dart';
import '../../notifications/domain/app_notification.dart';
import '../../requests/application/requests_providers.dart';
import '../../requests/domain/app_request.dart';
import '../../tracking/application/tracker_control.dart';
import '../../tracking/application/tracker_providers.dart';
import '../../tracking/domain/tracker_status.dart';
import '../../tracking/presentation/duty_setup_page.dart';
import '../../tracking/service/battery_alerts.dart';
import '../../users/application/users_providers.dart';
import '../../users/domain/profile.dart';
import '../../visits/application/visits_providers.dart';
import '../../visits/data/visit_outbox.dart';
import '../../visits/domain/visit.dart';
import '../../visits/presentation/visit_rows.dart';
import '../application/duty_providers.dart';
import '../application/phone_battery.dart';
import '../domain/duty_day.dart';
import '../domain/duty_failure.dart';
import '../domain/duty_home.dart';
import 'duty_card.dart';
import 'duty_off_sheet.dart';

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
      onResume: () {
        unawaited(ref.read(dutyHomeProvider.notifier).refresh());
        unawaited(_sendWaitingVisits());
      },
    );
    _battery = ref
        .read(trackerControlProvider)
        .batteryWarnings
        .listen(_showBatteryWarning);
    // Elapsed time, and the 5:00 / 8:30 window, move on their own.
    _ticker = Timer.periodic(const Duration(seconds: 30), (Timer t) {
      if (!mounted) return;
      setState(() {});
      // Visits kept on the phone without internet: try once a minute.
      if (t.tick.isEven) unawaited(_sendWaitingVisits());
      // On duty: the km on the card and the battery, every 5 minutes.
      if (t.tick % 10 == 0 && _onDutyNow()) {
        ref.invalidate(phoneBatteryProvider);
        unawaited(_controller.refresh());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_sendWaitingVisits()),
    );
  }

  /// Sends visits kept on the phone while there was no internet (M10).
  Future<void> _sendWaitingVisits() async {
    final AuthStatus status = ref.read(authStatusProvider);
    if (status is! SignedIn) return;
    final int sent = await ref.read(visitSenderProvider).sendAll(status.userId);
    if (!mounted) return;
    if (sent > 0) ref.invalidate(dayVisitsProvider);
    ref.invalidate(pendingVisitsProvider);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_battery?.cancel());
    _ticker?.cancel();
    super.dispose();
  }

  DutyHomeController get _controller => ref.read(dutyHomeProvider.notifier);

  bool _onDutyNow() =>
      ref
          .read(dutyHomeProvider)
          .value
          ?.phaseAt(ref.read(serverClockProvider).now()) ==
      DutyPhase.onDuty;

  /// True from the first tap until duty on has finished, so a quick second
  /// tap (before the button shows its spinner) does nothing.
  bool _dutyOnRunning = false;

  Future<void> _dutyOn() async {
    if (_dutyOnRunning) return;
    _dutyOnRunning = true;
    try {
      await _dutyOnSteps();
    } finally {
      _dutyOnRunning = false;
    }
  }

  Future<void> _dutyOnSteps() async {
    final List<TrackerRequirement> missing = await _controller
        .missingRequirements();
    if (!mounted) return;
    if (missing.any((TrackerRequirement r) => r.required)) {
      if (!await showTrackingSetup(context)) return;
    } else if (missing.contains(TrackerRequirement.batteryOptimization)) {
      // Not required: asked at most once a week (L52).
      await _controller.askBatteryIfDue();
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
    final bool ok = await showDutyOffSheet(
      context,
      day: day,
      now: ref.read(serverClockProvider).now(),
    );
    if (!ok || !mounted) return;
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
    } else if (outcome!.savedOffline) {
      _snack('No internet. Duty off is saved and will be sent by itself.');
    } else if (outcome.isShort) {
      _snack('Duty off done. The admin will decide your day.');
    } else {
      _snack('Duty off done. Thank you.');
    }
  }

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

  /// A battery warning from the tracker, shown as a banner until closed.
  int? _batteryLevel;

  void _showBatteryWarning(int level) {
    if (mounted) setState(() => _batteryLevel = level);
  }

  /// "Turn on location": opens the phone's setting for what stopped the
  /// route, then checks again.
  Future<void> _fixTracking(TrackerProblem problem) async {
    final TrackerControl tracker = ref.read(trackerControlProvider);
    switch (problem) {
      case TrackerProblem.locationOff:
        await tracker.request(TrackerRequirement.locationService);
      case TrackerProblem.permissionOff:
        await tracker.request(TrackerRequirement.locationPermission);
      case TrackerProblem.gps:
        break;
    }
    if (mounted) await _controller.refresh();
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
    // The admin allowed duty on today: show the Duty on button at once (L81).
    ref.listen<AsyncValue<List<AppNotification>>>(notificationsProvider, (
      AsyncValue<List<AppNotification>>? before,
      AsyncValue<List<AppNotification>> now,
    ) {
      if (newDutyOnAllowed(before?.value, now.value)) {
        unawaited(_controller.refresh());
      }
    });
    final DateTime now = ref.read(serverClockProvider).now();
    return Scaffold(
      backgroundColor: DsColors.surface,
      body: SafeArea(
        bottom: false,
        child: home.when(
          skipLoadingOnRefresh: true,
          data: (DutyHome value) => RefreshIndicator(
            onRefresh: _controller.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                DsSpace.gutter,
                DsSpace.lg,
                DsSpace.gutter,
                DsSpace.xl,
              ),
              children: _sections(value, now),
            ),
          ),
          error: (Object e, _) => Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DsSpace.gutter,
                  DsSpace.lg,
                  DsSpace.gutter,
                  0,
                ),
                child: _HomeHeader(now: now),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DsSpace.gutter),
                    child: DsErrorState(
                      title: 'Home could not be loaded',
                      message: mapDutyError(e).message,
                      onRetry: () => ref.invalidate(dutyHomeProvider),
                    ),
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  /// Home, top to bottom (design v2): header, warnings, duty card, quick
  /// actions, today's visits.
  List<Widget> _sections(DutyHome value, DateTime now) {
    final DutyPhase phase = value.phaseAt(now);
    final bool tracking =
        phase == DutyPhase.onDuty || phase == DutyPhase.offSaved;
    final TrackerStatus? status = tracking
        ? ref.watch(trackerStatusProvider).value
        : null;
    final DutyDay? day = value.today;
    final bool onDuty = phase == DutyPhase.onDuty;
    final List<Widget> banners = <Widget>[
      if (!value.serverReachable || (status?.offline ?? false))
        DsBanner(
          kind: DsBannerKind.offline,
          title: "You're offline",
          message: _offlineMessage(tracking, status?.pendingPoints ?? 0),
        ),
      if (onDuty && status?.problem != null)
        DsBanner(
          kind: DsBannerKind.danger,
          title: 'Tracking stopped',
          message: _stoppedMessage(status!),
          actionLabel: status.problem == TrackerProblem.gps
              ? 'Try again'
              : 'Turn on location',
          onAction: () => unawaited(_fixTracking(status.problem!)),
        ),
      if (value.trackingProblem case final String problem)
        DsBanner(
          kind: DsBannerKind.danger,
          title: 'Route is not being recorded',
          message: problem,
          actionLabel: 'Try again',
          onAction: () => unawaited(_controller.refresh()),
        ),
      if (_batteryLevel case final int level)
        DsBanner(
          kind: level <= 10 ? DsBannerKind.danger : DsBannerKind.warning,
          title: 'Battery $level%',
          message: batteryMessage(level),
          actionLabel: 'OK',
          onAction: () => setState(() => _batteryLevel = null),
        ),
    ];
    return <Widget>[
      _HomeHeader(now: now),
      for (final Widget banner in banners) ...<Widget>[
        const SizedBox(height: DsSpace.lg),
        banner,
      ],
      const SizedBox(height: DsSpace.lg),
      DutyCard(
        home: value,
        now: now,
        busy: _busy,
        onDutyOn: _dutyOn,
        onDutyOff: _dutyOff,
      ),
      const SizedBox(height: DsSpace.lg),
      _QuickActions(addVisitDayId: onDuty ? day!.id : null),
      if (day != null && day.dutyOnAt != null) ...<Widget>[
        const SizedBox(height: DsSpace.lg),
        _VisitsCard(day: day),
      ],
    ];
  }
}

/// The offline banner's text: the route is kept on the phone while on duty.
String _offlineMessage(bool tracking, int pending) {
  if (!tracking) return 'Showing what is saved on this phone.';
  const String base =
      "Your route is still recording. It's saved on this phone and uploads "
      "when you're back online.";
  if (pending == 0) return base;
  return '$base\n$pending ${pending == 1 ? 'point' : 'points'} waiting to '
      'upload';
}

/// "Location is off, so your route isn't being recorded since 11:05 AM."
String _stoppedMessage(TrackerStatus status) {
  final String since = status.problemSince == null
      ? ''
      : ' since ${IstFormat.time(status.problemSince!)}';
  return switch (status.problem!) {
    TrackerProblem.locationOff =>
      "Location is off, so your route isn't being recorded$since.",
    TrackerProblem.permissionOff =>
      "Location permission is off, so your route isn't being "
          'recorded$since.',
    TrackerProblem.gps =>
      "The GPS has a problem, so your route isn't being recorded$since.",
  };
}

/// Initials, today's date, "Hello, Rahul", and the bell.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? name = ref.watch(myProfileProvider).value?.fullName;
    final int unread = ref.watch(unreadCountProvider);
    return Row(
      children: <Widget>[
        Semantics(
          button: true,
          label: 'My profile',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => context.go(Routes.userProfile),
            child: Container(
              width: DsSize.tap,
              height: DsSize.tap,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: DsColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: DsColors.white, width: 3),
              ),
              child: name == null
                  ? const Icon(DsIcons.profile, size: 20, color: DsColors.white)
                  : Text(
                      initialsOf(name),
                      style: DsText.button.copyWith(color: DsColors.white),
                    ),
            ),
          ),
        ),
        const SizedBox(width: DsSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                IstFormat.dayDate(now),
                style: DsText.label.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                name == null ? 'Hello' : 'Hello, ${firstNameOf(name)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsText.title,
              ),
            ],
          ),
        ),
        DsIconButton(
          icon: DsIcons.bell,
          label: 'Notifications',
          badge: unread,
          onPressed: () => context.push(Routes.userNotifications),
        ),
      ],
    );
  }
}

/// "Rahul" for "Rahul Das".
String firstNameOf(String name) => name.trim().split(RegExp(r'\s+')).first;

/// Add visit (only on duty), My route, and Requests with the number still
/// waiting for the admin.
class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.addVisitDayId});

  /// Today's duty day while on duty; null hides Add visit.
  final int? addVisitDayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int waiting =
        ref
            .watch(myRequestsProvider)
            .value
            ?.where((AppRequest r) => r.isPending)
            .length ??
        0;
    final int? dayId = addVisitDayId;
    return Row(
      children: <Widget>[
        if (dayId != null) ...<Widget>[
          Expanded(
            child: _ActionTile(
              icon: DsIcons.camera,
              label: 'Add visit',
              primary: true,
              onTap: () => context.push(Routes.userAddVisit(dayId)),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: _ActionTile(
            icon: DsIcons.map,
            label: 'My route',
            onTap: () => context.go(Routes.userMap),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: DsIcons.requests,
            label: 'Requests',
            iconColor: DsStatus.leave.text,
            iconBackground: DsStatus.leave.tint,
            badge: waiting,
            badgeLabel: '$waiting waiting',
            onTap: () => context.push(Routes.userRequests),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.iconColor = DsColors.primary,
    this.iconBackground = DsColors.primaryTint,
    this.badge = 0,
    this.badgeLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Brand blue tile (Add visit); the others are white.
  final bool primary;
  final Color iconColor;
  final Color iconBackground;
  final int badge;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: badge > 0 ? '$label, ${badgeLabel ?? badge}' : label,
    excludeSemantics: true,
    child: Material(
      color: primary ? DsColors.primary : DsColors.white,
      borderRadius: DsRadius.large,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 92,
          child: Stack(
            children: <Widget>[
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primary ? DsColors.deepRaised : iconBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: primary ? DsColors.white : iconColor,
                      ),
                    ),
                    const SizedBox(height: DsSpace.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DsSpace.xs,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsText.body.copyWith(
                          color: primary ? DsColors.white : DsColors.ink,
                          fontWeight: FontWeight.w700,
                          fontVariations: const <FontVariation>[
                            FontVariation('wght', 700),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: 10,
                  right: 12,
                  child: DsCountBadge(count: badge, waiting: true),
                ),
            ],
          ),
        ),
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
    final List<PendingVisit> waiting =
        ref.watch(pendingVisitsProvider).value ?? const <PendingVisit>[];
    final bool onDuty = day.status == DayStatus.onDuty;
    final List<Visit>? list = visits.value;
    final int count = (list?.length ?? 0) + waiting.length;
    final List<Widget> rows = <Widget>[
      for (int i = 0; i < (list?.length ?? 0); i++)
        VisitTimelineRow(
          visit: list![i],
          isLast: i == list.length - 1 && waiting.isEmpty,
        ),
      for (int i = 0; i < waiting.length; i++)
        PendingVisitTimelineRow(
          visit: waiting[i],
          isLast: i == waiting.length - 1,
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(DsSpace.lg),
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text('Visits today', style: DsText.section),
              ),
              if (count > 0)
                DsTag(label: '$count of the day', status: DsStatus.onDuty),
            ],
          ),
          const SizedBox(height: DsSpace.sm),
          if (visits.hasError && list == null)
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Visits could not be loaded.',
                    style: DsText.body,
                  ),
                ),
                DsTextLink(
                  label: 'Try again',
                  onPressed: () => ref.invalidate(dayVisitsProvider(day.id)),
                ),
              ],
            )
          else if (list == null)
            const Padding(
              padding: EdgeInsets.all(DsSpace.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            Text(
              onDuty
                  ? 'No visits yet. Add one at each dealer, with a photo.'
                  : 'No visits today.',
              style: DsText.body.copyWith(color: DsColors.text2),
            )
          else
            ...rows,
        ],
      ),
    );
  }
}

/// True when [now] has an unread "duty on allowed" notification that
/// [before] did not have (L81).
bool newDutyOnAllowed(
  List<AppNotification>? before,
  List<AppNotification>? now,
) {
  final Set<int> seen = <int>{
    for (final AppNotification n in before ?? []) n.id,
  };
  return (now ?? const <AppNotification>[]).any(
    (AppNotification n) =>
        n.kind == dutyOnAllowedKind && n.unread && !seen.contains(n.id),
  );
}
