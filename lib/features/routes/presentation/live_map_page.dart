import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../duty/domain/duty_day.dart';
import '../../users/application/users_providers.dart';
import '../../users/domain/profile.dart';
import '../../users/presentation/account_button.dart';
import '../application/route_providers.dart';
import '../domain/live_position.dart';
import 'app_map.dart';

/// The admin's live map: everyone with a duty today, where they last were.
class LiveMapPage extends ConsumerStatefulWidget {
  const LiveMapPage({super.key});

  @override
  ConsumerState<LiveMapPage> createState() => _LiveMapPageState();
}

class _LiveMapPageState extends ConsumerState<LiveMapPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Positions arrive live; duty status and "no update" age move on their own.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      ref.invalidate(todayDaysProvider);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<LivePosition>> live = ref.watch(
      livePositionsProvider,
    );
    final AsyncValue<List<DutyDay>> days = ref.watch(todayDaysProvider);
    final AsyncValue<List<Profile>> people = ref.watch(usersListProvider);
    final DateTime now = ref.read(serverClockProvider).now();

    Widget body;
    if (live.hasError || days.hasError || people.hasError) {
      body = AppErrorView(
        onRetry: () {
          ref
            ..invalidate(livePositionsProvider)
            ..invalidate(todayDaysProvider)
            ..invalidate(usersListProvider);
        },
      );
    } else if (!live.hasValue || !days.hasValue || !people.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final List<LiveRow> rows = liveRows(
        positions: live.value!,
        days: days.value!,
        people: people.value!,
        now: now,
      );
      body = rows.isEmpty
          ? const Padding(
              padding: AppSpacing.screen,
              child: AppEmptyState(
                title: 'Nobody on duty yet',
                description: 'People appear here after duty on.',
                icon: Icons.location_on_rounded,
              ),
            )
          : _LiveBody(rows: rows, now: now);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live map'),
        actions: const <Widget>[AccountButton()],
      ),
      body: body,
    );
  }
}

/// One person on today's live map.
class LiveRow {
  const LiveRow({
    required this.name,
    required this.day,
    required this.position,
    required this.stale,
  });

  final String name;
  final DutyDay day;
  final LivePosition? position;
  final bool stale;

  bool get onDuty => day.status == DayStatus.onDuty;
}

/// Everyone who did duty on today, on duty first, then by name.
List<LiveRow> liveRows({
  required List<LivePosition> positions,
  required List<DutyDay> days,
  required List<Profile> people,
  required DateTime now,
}) {
  final Map<String, Profile> byId = <String, Profile>{
    for (final Profile p in people) p.id: p,
  };
  final Map<int, LivePosition> byDay = <int, LivePosition>{
    for (final LivePosition p in positions)
      if (p.dutyDayId != null) p.dutyDayId!: p,
  };
  final List<LiveRow> rows = <LiveRow>[
    for (final DutyDay d in days)
      if (d.dutyOnAt != null)
        LiveRow(
          name: byId[d.userId]?.fullName ?? 'Unknown',
          day: d,
          position: byDay[d.id],
          stale:
              d.status == DayStatus.onDuty &&
              (byDay[d.id]?.isStaleAt(now) ?? true),
        ),
  ];
  rows.sort((LiveRow a, LiveRow b) {
    if (a.onDuty != b.onDuty) return a.onDuty ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return rows;
}

class _LiveBody extends StatelessWidget {
  const _LiveBody({required this.rows, required this.now});

  final List<LiveRow> rows;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    void open(LiveRow r) => context.push(Routes.adminDay(r.day.id));
    return Column(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: AppMap(
            lines: const [],
            pins: <MapPin>[
              for (final LiveRow r in rows)
                if (r.position case final LivePosition p when r.onDuty)
                  MapPin(
                    id: r.day.id.toString(),
                    point: p.point,
                    kind: r.stale ? PinKind.personStale : PinKind.person,
                    title: r.name,
                    snippet: p.mocked
                        ? 'FAKE GPS at ${IstFormat.time(p.recordedAt)}. '
                              'Tap for route.'
                        : 'At ${IstFormat.time(p.recordedAt)}. Tap for route.',
                    onTap: () => open(r),
                  ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int i) {
              final LiveRow r = rows[i];
              final LivePosition? p = r.position;
              final String state = !r.onDuty
                  ? r.day.status.label
                  : p == null
                  ? 'On duty · no position yet'
                  : r.stale
                  ? 'No update since ${IstFormat.time(p.recordedAt)}'
                  : 'On duty · ${IstFormat.time(p.recordedAt)}';
              return ListTile(
                leading: Icon(
                  Icons.circle,
                  size: 14,
                  color: !r.onDuty
                      ? AppColors.statusOff
                      : p?.mocked ?? false
                      ? AppColors.statusSuspect
                      : r.stale
                      ? AppColors.statusStale
                      : AppColors.statusActive,
                ),
                title: Text(r.name),
                subtitle: Text(
                  <String>[
                    state,
                    if (r.onDuty && (p?.mocked ?? false)) 'Fake GPS',
                    if (p?.battery case final int b when r.onDuty)
                      'Battery $b%',
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => open(r),
              );
            },
          ),
        ),
      ],
    );
  }
}
