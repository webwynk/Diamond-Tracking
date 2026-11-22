import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_cards.dart';
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../../duty/domain/duty_day.dart';
import '../../duty/presentation/day_status_look.dart';
import '../../requests/application/requests_providers.dart';
import '../../requests/domain/app_request.dart';
import '../application/route_providers.dart';
import '../domain/history_month.dart';
import 'route_parts.dart' show formatKm;

/// Which days the list shows.
enum _Filter {
  all('All'),
  present('Present'),
  halfDay('Half day'),
  waiting('Waiting'),
  leave('Leave'),
  absent('Absent');

  const _Filter(this.label);

  final String label;

  bool matches(DutyDay d) => switch (this) {
    _Filter.all => true,
    // Today's running duty sits with the present days.
    _Filter.present =>
      d.status == DayStatus.present || d.status == DayStatus.onDuty,
    _Filter.halfDay => d.status == DayStatus.halfDay,
    _Filter.waiting => d.status == DayStatus.pending,
    _Filter.leave => d.status == DayStatus.leave,
    _Filter.absent => d.status == DayStatus.absent,
  };
}

/// Duty days by month (design v2, History): a month summary with "Days
/// counted", this week at a glance, filter chips and a card per day: the
/// employee's History tab. (The admin's is DutyHistoryPage.)
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({required this.dayRoute, super.key, this.requestRoute});

  /// The page to open for a day, given its id.
  final String Function(int dayId) dayRoute;

  /// The page for a request, given its id. Set for the employee: a leave
  /// day then opens its leave request. Null: leave days do not open.
  final String Function(int requestId)? requestRoute;

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  /// 0 is the current month, 1 the one before, and so on.
  int _monthIndex = 0;
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final AuthStatus status = ref.watch(authStatusProvider);
    final String? who = status is SignedIn ? status.userId : null;
    if (who == null) return const SizedBox.shrink();
    final AsyncValue<List<DutyDay>> days = ref.watch(historyProvider(who));
    final List<AppRequest> myRequests = widget.requestRoute == null
        ? const <AppRequest>[]
        : (ref.watch(myRequestsProvider).value ?? const <AppRequest>[]);
    final DateTime now = ref.watch(serverClockProvider).now();
    final DateTime today = Ist.dateOf(now);
    final DateTime earliest = today.subtract(const Duration(days: historyDays));
    final List<DateTime> months = HistoryMonth.monthsBetween(earliest, today);
    final int index = _monthIndex.clamp(0, months.length - 1);
    final bool canPop = context.canPop();

    return Scaffold(
      backgroundColor: DsColors.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(historyProvider(who).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DsSpace.lg,
              DsSpace.md,
              DsSpace.lg,
              DsSpace.xl,
            ),
            children: <Widget>[
              _Header(
                title: 'History',
                onBack: canPop ? () => context.pop() : null,
                month: months[index],
                onPrevious: index < months.length - 1
                    ? () => setState(() => _monthIndex = index + 1)
                    : null,
                onNext: index > 0
                    ? () => setState(() => _monthIndex = index - 1)
                    : null,
              ),
              const SizedBox(height: DsSpace.lg),
              ...days.when(
                skipLoadingOnRefresh: true,
                data: (List<DutyDay> all) => _content(
                  HistoryMonth.of(
                    months[index],
                    all,
                    today: today,
                    earliest: earliest,
                  ),
                  all,
                  myRequests,
                  today: today,
                  now: now,
                  showWeek: index == 0,
                ),
                error: (_, _) => <Widget>[
                  DsErrorState(
                    title: "Couldn't load your days",
                    message: 'Check the internet and try again.',
                    onRetry: () => ref.invalidate(historyProvider(who)),
                  ),
                ],
                loading: () => const <Widget>[
                  Padding(
                    padding: EdgeInsets.only(top: DsSpace.xxl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    HistoryMonth month,
    List<DutyDay> all,
    List<AppRequest> myRequests, {
    required DateTime today,
    required DateTime now,
    required bool showWeek,
  }) {
    if (all.isEmpty) {
      return const <Widget>[
        DsEmptyState(
          title: 'No days yet',
          message: 'Days appear here after the first duty.',
          icon: DsIcons.history,
        ),
      ];
    }
    final List<_Filter> chips = <_Filter>[
      for (final _Filter f in _Filter.values)
        if (f == _Filter.all || month.days.any(f.matches)) f,
    ];
    final _Filter filter = chips.contains(_filter) ? _filter : _Filter.all;
    final List<DutyDay> shown = month.days.where(filter.matches).toList();
    return <Widget>[
      _MonthSummary(month: month),
      if (showWeek) ...<Widget>[
        const SizedBox(height: DsSpace.lg),
        _WeekStrip(all: all, today: today),
      ],
      const SizedBox(height: DsSpace.md),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final _Filter f in chips) ...<Widget>[
              DsFilterChip(
                label: f.label,
                selected: f == filter,
                count: month.days.where(f.matches).length,
                onTap: () => setState(() => _filter = f),
              ),
              const SizedBox(width: DsSpace.sm),
            ],
          ],
        ),
      ),
      const SizedBox(height: DsSpace.sm),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.xl),
          child: Text(
            'No days this month.',
            textAlign: TextAlign.center,
            style: DsText.body.copyWith(color: DsColors.text2),
          ),
        ),
      for (final DutyDay d in shown) ...<Widget>[
        _DayCard(
          day: d,
          now: now,
          onTap: d.dutyOnAt != null
              ? () => context.push(widget.dayRoute(d.id))
              : _leaveRequest(d, myRequests) == null
              ? null
              : () => context.push(
                  widget.requestRoute!(_leaveRequest(d, myRequests)!.id),
                ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

/// The approved leave request that covers a leave day, if known.
AppRequest? _leaveRequest(DutyDay d, List<AppRequest> requests) {
  if (d.status != DayStatus.leave) return null;
  for (final AppRequest r in requests) {
    if (r.kind == RequestKind.leave &&
        r.status == RequestStatus.approved &&
        r.dates.contains(d.day)) {
      return r;
    }
  }
  return null;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onBack,
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final VoidCallback? onBack;
  final DateTime month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String label, VoidCallback? onTap) => Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: DsColors.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 36,
            child: Icon(
              icon,
              size: 18,
              color: onTap == null ? DsColors.line : DsColors.ink,
            ),
          ),
        ),
      ),
    );
    return Row(
      children: <Widget>[
        if (onBack != null) ...<Widget>[
          DsIconButton(icon: DsIcons.back, label: 'Back', onPressed: onBack),
          const SizedBox(width: DsSpace.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: DsText.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Text('Last 90 days', style: DsText.label),
            ],
          ),
        ),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
          decoration: const BoxDecoration(
            color: DsColors.white,
            borderRadius: DsRadius.pill,
            boxShadow: DsShadow.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              step(DsIcons.back, 'Previous month', onPrevious),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm),
                child: Text(
                  DateFormat('MMMM').format(month),
                  style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              step(DsIcons.forward, 'Next month', onNext),
            ],
          ),
        ),
      ],
    );
  }
}

/// The deep card: Days counted, the number of days, a bar and the counts.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.month});

  final HistoryMonth month;

  static const List<(DayStatus, String, Color)> _parts =
      <(DayStatus, String, Color)>[
        (DayStatus.present, 'Present', Color(0xFF4ADE80)),
        (DayStatus.halfDay, 'Half day', DsColors.sky),
        (DayStatus.leave, 'Leave', Color(0xFFC4B5FD)),
        (DayStatus.pending, 'Waiting', Color(0xFFFBBF24)),
        (DayStatus.absent, 'Absent', Color(0xFFF87171)),
      ];

  @override
  Widget build(BuildContext context) {
    final DateFormat dayMonth = DateFormat('d MMM');
    final String range = month.from.month == month.to.month
        ? '${month.from.day}–${dayMonth.format(month.to)}'
        : '${dayMonth.format(month.from)}–${dayMonth.format(month.to)}';
    final int total = _parts.fold(
      0,
      (int sum, (DayStatus, String, Color) p) => sum + month.count(p.$1),
    );
    return Semantics(
      container: true,
      label:
          'Days counted ${formatDaysCounted(month.daysCounted)}, '
          '$range',
      child: DsHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Days counted · $range',
                        style: DsText.caption.copyWith(color: DsColors.skyText),
                      ),
                      Text(
                        formatDaysCounted(month.daysCounted),
                        style: DsText.number.copyWith(color: DsColors.white),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DsSpace.md,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: DsColors.deepRaised,
                    borderRadius: DsRadius.pill,
                  ),
                  child: Text(
                    '${month.calendarDays} days · every day counts',
                    style: DsText.caption.copyWith(
                      color: DsColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: DsRadius.pill,
              child: SizedBox(
                height: 10,
                child: total == 0
                    ? Container(color: DsColors.deepRaised)
                    : Row(
                        children: <Widget>[
                          for (final (DayStatus s, String _, Color c) in _parts)
                            if (month.count(s) > 0)
                              Expanded(
                                flex: month.count(s),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 3),
                                  decoration: BoxDecoration(
                                    color: c,
                                    borderRadius: DsRadius.pill,
                                  ),
                                ),
                              ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                for (final (DayStatus s, String label, Color c) in _parts)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${month.count(s)}',
                          style: DsText.section.copyWith(color: DsColors.white),
                        ),
                        Row(
                          children: <Widget>[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DsText.micro.copyWith(
                                  color: DsColors.skyText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Monday to Sunday of this week: a circle per date, today filled, a dot in
/// the day's status colour.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.all, required this.today});

  final List<DutyDay> all;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final DateTime monday = today.subtract(Duration(days: today.weekday - 1));
    final Map<DateTime, DutyDay> byDate = <DateTime, DutyDay>{
      for (final DutyDay d in all) d.day: d,
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.md, horizontal: 6),
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.large,
      ),
      child: Semantics(
        label: 'This week',
        container: true,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < 7; i++)
              Expanded(
                child: _WeekDay(
                  date: monday.add(Duration(days: i)),
                  day: byDate[monday.add(Duration(days: i))],
                  isToday: monday.add(Duration(days: i)) == today,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.date,
    required this.day,
    required this.isToday,
  });

  final DateTime date;
  final DutyDay? day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final DutyDay? d = day;
    return Semantics(
      label:
          '${DateFormat('EEEE d').format(date)}'
          '${d == null ? '' : ', ${dayStatusText(d)}'}',
      excludeSemantics: true,
      child: Column(
        children: <Widget>[
          Text(
            DateFormat('E').format(date).substring(0, 1),
            style: DsText.micro.copyWith(
              color: DsColors.text2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday ? DsColors.primary : DsColors.surface,
              border: isToday
                  ? Border.all(color: DsColors.primaryTint, width: 3)
                  : null,
            ),
            child: Text(
              '${date.day}',
              style: DsText.label.copyWith(
                fontWeight: FontWeight.w700,
                color: isToday
                    ? DsColors.white
                    : (d == null ? DsColors.text2 : DsColors.ink),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: d == null ? Colors.transparent : dayStatusTone(d).dot,
            ),
          ),
        ],
      ),
    );
  }
}

/// One day: date tile, status, time on duty, times and distance, and a bar
/// filling up to the 10 hours of a full day.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.now, required this.onTap});

  final DutyDay day;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final DsStatus s = dayStatusTone(day);
    final bool leave = day.status == DayStatus.leave;
    final Duration? length = dutyLength(day, now);
    final DateTime? on = day.dutyOnAt;
    final String sub = switch (day.status) {
      DayStatus.leave => 'Approved leave',
      DayStatus.absent when on == null => 'No duty this day',
      _ when on == null => 'No duty',
      _ => <String>[
        '${IstFormat.time(on)} → '
            '${day.dutyOffAt == null ? 'now' : IstFormat.time(day.dutyOffAt!)}'
            '${day.autoEnded ? ' (auto off)' : ''}',
        if (day.distanceM case final int m) formatKm(m),
      ].join(' · '),
    };
    final DateTime wall = day.day;
    return Material(
      color: leave ? s.tint : DsColors.white,
      borderRadius: DsRadius.large,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 56,
                decoration: BoxDecoration(
                  color: day.status == DayStatus.onDuty
                      ? DsColors.primary
                      : (leave ? DsColors.white : s.tint),
                  borderRadius: DsRadius.medium,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      '${wall.day}',
                      style: DsText.section.copyWith(
                        height: 1.1,
                        color: day.status == DayStatus.onDuty
                            ? DsColors.white
                            : s.text,
                      ),
                    ),
                    Text(
                      DateFormat('E').format(wall),
                      style: DsText.micro.copyWith(
                        fontWeight: FontWeight.w600,
                        color: day.status == DayStatus.onDuty
                            ? DsColors.white
                            : s.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: DsStatusPill(
                            status: s,
                            label: dayStatusText(day),
                          ),
                        ),
                        const Spacer(),
                        if (length != null)
                          Text(
                            IstFormat.hoursMinutes(length),
                            style: DsText.label.copyWith(
                              color: DsColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sub,
                      style: DsText.label.copyWith(fontWeight: FontWeight.w400),
                    ),
                    if (length != null) ...<Widget>[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: DsRadius.pill,
                        child: LinearProgressIndicator(
                          value: (length.inMinutes / fullDay.inMinutes)
                              .clamp(0, 1)
                              .toDouble(),
                          minHeight: 6,
                          backgroundColor: DsColors.disabled,
                          color: s.dot,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
