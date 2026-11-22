import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/routes.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../duty/domain/duty_day.dart';
import '../../duty/presentation/day_status_look.dart';
import '../../reports/application/reports_providers.dart';
import '../../reports/domain/report.dart';
import '../../reports/presentation/export_pdf_sheet.dart';
import '../../reports/presentation/report_parts.dart';
import '../../users/application/users_providers.dart';
import '../../users/domain/profile.dart';
import '../../visits/application/visits_providers.dart';
import '../application/route_providers.dart';
import '../domain/history_month.dart';
import 'change_day_status_sheet.dart';
import 'route_parts.dart' show formatKm;

/// The admin's "Duty history" for one person (design v2): the month's
/// totals, a calendar coloured by day, and the picked day with its route.
class DutyHistoryPage extends ConsumerStatefulWidget {
  const DutyHistoryPage({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<DutyHistoryPage> createState() => _DutyHistoryPageState();
}

class _DutyHistoryPageState extends ConsumerState<DutyHistoryPage> {
  /// 0 is the current month, 1 the one before, and so on.
  int _monthIndex = 0;

  /// The picked date; null picks the latest day of the month shown.
  DateTime? _picked;

  Future<void> _download(Profile? p, DateTime month, DateTime today) async {
    final ReportRange range = ReportRange(
      DateTime.utc(month.year, month.month),
      month.year == today.year && month.month == today.month
          ? today
          : DateTime.utc(month.year, month.month + 1, 0),
    );
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final List<PersonReport> all = await ref.read(
        reportProvider(range).future,
      );
      final List<PersonReport> mine = all
          .where((PersonReport r) => r.userId == widget.userId)
          .toList();
      if (!mounted) return;
      if (mine.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No records in this month.')),
        );
        return;
      }
      await showExportPdfSheet(
        context,
        range: range,
        people: mine,
        who: p?.fullName ?? mine.single.name,
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't load the report. Check the internet."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Profile? person = ref.watch(userByIdProvider(widget.userId)).value;
    final AsyncValue<List<DutyDay>> history = ref.watch(
      historyProvider(widget.userId),
    );
    final DateTime now = ref.watch(serverClockProvider).now();
    final DateTime today = Ist.dateOf(now);
    final DateTime earliest = today.subtract(const Duration(days: historyDays));
    final List<DateTime> months = HistoryMonth.monthsBetween(earliest, today);
    final int index = _monthIndex.clamp(0, months.length - 1);
    final List<DutyDay> all = history.value ?? const <DutyDay>[];
    final HistoryMonth month = HistoryMonth.of(
      months[index],
      all,
      today: today,
      earliest: earliest,
    );
    final Map<DateTime, DutyDay> byDate = <DateTime, DutyDay>{
      for (final DutyDay d in month.days) d.day: d,
    };
    final DateTime picked =
        _picked != null &&
            !_picked!.isBefore(month.from) &&
            !_picked!.isAfter(month.to)
        ? _picked!
        : month.to;
    final ({int present, int halfDay, int leave, int absent}) c = statusCounts(
      month.days.map((DutyDay d) => d.status),
    );
    final int minutes = month.days.fold(
      0,
      (int s, DutyDay d) => s + (dutyLength(d, now)?.inMinutes ?? 0),
    );
    final int metres = month.days.fold(
      0,
      (int s, DutyDay d) => s + (d.distanceM ?? 0),
    );

    return Scaffold(
      backgroundColor: DsColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(historyProvider(widget.userId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DsSpace.gutter,
              DsSpace.md,
              DsSpace.gutter,
              28,
            ),
            children: <Widget>[
              Row(
                children: <Widget>[
                  DsIconButton(
                    icon: DsIcons.back,
                    label: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: DsStatus.present.tint,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      person == null ? '' : initialsOf(person.fullName),
                      style: DsText.label.copyWith(
                        color: DsStatus.present.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Semantics(
                          header: true,
                          child: Text(
                            person?.fullName ?? ' ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsText.section,
                          ),
                        ),
                        const Text(
                          'Duty history · last 90 days',
                          style: DsText.caption,
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    container: true,
                    button: true,
                    label: "Download this person's report",
                    excludeSemantics: true,
                    child: Material(
                      color: DsColors.ink,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _download(person, months[index], today),
                        child: const SizedBox.square(
                          dimension: 44,
                          child: Icon(
                            DsIcons.download,
                            size: 18,
                            color: DsColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (history.hasError && !history.hasValue)
                DsErrorState(
                  title: "Couldn't load the days",
                  message: 'Check the internet and try again.',
                  onRetry: () => ref.invalidate(historyProvider(widget.userId)),
                )
              else if (!history.hasValue)
                const Padding(
                  padding: EdgeInsets.only(top: DsSpace.xxl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...<Widget>[
                StatusTotals(
                  present: c.present,
                  halfDay: c.halfDay,
                  leave: c.leave,
                  absent: c.absent,
                  big: true,
                ),
                const SizedBox(height: 14),
                _Calendar(
                  month: month,
                  byDate: byDate,
                  today: today,
                  picked: picked,
                  summary: '${minutes ~/ 60} h · ${formatKm(metres)}',
                  onPrevious: index < months.length - 1
                      ? () => setState(() {
                          _monthIndex = index + 1;
                          _picked = null;
                        })
                      : null,
                  onNext: index > 0
                      ? () => setState(() {
                          _monthIndex = index - 1;
                          _picked = null;
                        })
                      : null,
                  onPick: (DateTime d) => setState(() => _picked = d),
                ),
                const SizedBox(height: 14),
                _PickedDay(date: picked, day: byDate[picked]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The colours of a day on the calendar.
DsStatus _tone(DutyDay d) => switch (d.status) {
  DayStatus.present => DsStatus.onDuty,
  DayStatus.onDuty => DsStatus.present,
  _ => dayStatusTone(d),
};

class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.month,
    required this.byDate,
    required this.today,
    required this.picked,
    required this.summary,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final HistoryMonth month;
  final Map<DateTime, DutyDay> byDate;
  final DateTime today;
  final DateTime picked;
  final String summary;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final DateTime first = month.month;
    final int daysInMonth = DateTime.utc(first.year, first.month + 1, 0).day;
    // Sunday first, as on the design.
    final int lead = first.weekday % 7;
    final int cells = ((lead + daysInMonth) / 7).ceil() * 7;
    Widget arrow(IconData icon, String label, VoidCallback? onTap) => Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: onTap == null
            ? const Color(0xFFF8FAFC)
            : const Color(0xFFEEF2F6),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 38,
            child: Icon(
              icon,
              size: 16,
              color: onTap == null ? const Color(0xFFCBD5E1) : DsColors.ink,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              arrow(DsIcons.back, 'Previous month', onPrevious),
              Expanded(
                child: Column(
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        DateFormat('MMMM yyyy').format(first),
                        style: DsText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      summary,
                      style: DsText.micro.copyWith(color: DsColors.text2),
                    ),
                  ],
                ),
              ),
              arrow(DsIcons.forward, 'Next month', onNext),
            ],
          ),
          const SizedBox(height: DsSpace.md),
          Row(
            children: <Widget>[
              for (final String w in <String>[
                'S',
                'M',
                'T',
                'W',
                'T',
                'F',
                'S',
              ])
                Expanded(
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: DsText.micro.copyWith(
                      color: DsColors.text2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (int row = 0; row < cells ~/ 7; row++) ...<Widget>[
            if (row > 0) const SizedBox(height: 6),
            Row(
              children: <Widget>[
                for (int col = 0; col < 7; col++) ...<Widget>[
                  if (col > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _cell(row * 7 + col - lead + 1, daysInMonth, first),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: DsSpace.md),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: <Widget>[
              for (final (DsStatus s, String l) in <(DsStatus, String)>[
                (DsStatus.onDuty, 'Present'),
                (DsStatus.halfDay, 'Half day'),
                (DsStatus.leave, 'Leave'),
                (DsStatus.present, 'On duty'),
                (DsStatus.absent, 'Absent'),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: s.dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l,
                      style: DsText.micro.copyWith(color: DsColors.text2),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(int n, int daysInMonth, DateTime first) {
    if (n < 1 || n > daysInMonth) return const SizedBox(height: 42);
    final DateTime date = DateTime.utc(first.year, first.month, n);
    final bool outside = date.isBefore(month.from) || date.isAfter(month.to);
    final DutyDay? d = byDate[date];
    final DsStatus? t = d == null ? null : _tone(d);
    final bool on = date == picked;
    final Color bg = outside
        ? DsColors.white
        : on
        ? (t?.text ?? DsColors.text2)
        : (t?.tint ?? DsColors.surface);
    final Color fg = outside
        ? const Color(0xFFCBD5E1)
        : on
        ? DsColors.white
        : (t?.text ?? DsColors.text2);
    return Semantics(
      container: true,
      button: !outside,
      selected: on,
      enabled: !outside,
      label:
          '${DateFormat('d MMMM').format(date)}, '
          '${outside
              ? 'not in the last 90 days'
              : d == null
              ? 'nothing recorded'
              : dayStatusText(d)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: outside ? null : () => onPick(date),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: DsRadius.medium,
            border: outside ? Border.all(color: const Color(0xFFEEF2F6)) : null,
            boxShadow: on ? DsShadow.card : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '$n',
                style: DsText.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: t == null || outside
                      ? Colors.transparent
                      : on
                      ? DsColors.white
                      : t.dot,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The picked day: date, status and times; a worked day shows its bar,
/// figures and route, any other day a note and "Change day status".
class _PickedDay extends ConsumerWidget {
  const _PickedDay({required this.date, required this.day});

  final DateTime date;
  final DutyDay? day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DutyDay? d = day;
    final DsStatus t = d == null ? DsStatus.off : _tone(d);
    final bool worked = d?.dutyOnAt != null;
    final DateTime now = ref.watch(serverClockProvider).now();
    final Duration? length = d == null ? null : dutyLength(d, now);
    final int visits = worked
        ? ref.watch(dayVisitsProvider(d!.id)).value?.length ?? 0
        : 0;
    final String times = worked
        ? '${IstFormat.time(d!.dutyOnAt!)} → '
              '${d.dutyOffAt == null ? 'now' : IstFormat.time(d.dutyOffAt!)}'
        : d?.status == DayStatus.leave
        ? 'Approved by admin'
        : 'Nothing recorded';
    final String note = switch (d?.status) {
      DayStatus.leave =>
        '${d!.leaveType?.label ?? 'Leave'}, approved. Not counted as absent.',
      DayStatus.absent =>
        'No duty on and no leave, so the day is Absent. You can change the '
            'status if needed.',
      DayStatus.pending => 'Waiting for a decision.',
      _ => 'No record for this day.',
    };
    Widget figure(String value, String label) => Expanded(
      child: Semantics(
        container: true,
        label: '$label $value',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            color: DsColors.surface,
            borderRadius: DsRadius.medium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(label, style: DsText.micro.copyWith(color: DsColors.text2)),
            ],
          ),
        ),
      ),
    );
    double place(DateTime x) =>
        ((Ist.minuteOfDay(x) - 300) / 1080).clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.all(DsSpace.lg),
      decoration: BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.large,
        boxShadow: <BoxShadow>[BoxShadow(color: t.tint, spreadRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 56,
                decoration: BoxDecoration(
                  color: d == null ? const Color(0xFF94A3B8) : t.text,
                  borderRadius: DsRadius.medium,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      DateFormat('EEE').format(date).toUpperCase(),
                      style: DsText.micro.copyWith(
                        color: DsColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${date.day}',
                      style: DsText.title.copyWith(
                        color: DsColors.white,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (d != null)
                      Container(
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: t.tint,
                          borderRadius: DsRadius.pill,
                        ),
                        child: Text(
                          dayStatusText(d),
                          style: DsText.caption.copyWith(
                            color: t.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: DsSpace.xs),
                    Text(
                      times,
                      style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpace.md),
          if (worked) ...<Widget>[
            ClipRRect(
              borderRadius: DsRadius.pill,
              child: SizedBox(
                height: 8,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) {
                    final double a = place(d!.dutyOnAt!) * box.maxWidth;
                    final double b = place(d.dutyOffAt ?? now) * box.maxWidth;
                    return Stack(
                      children: <Widget>[
                        Container(color: const Color(0xFFEEF2F6)),
                        Positioned(
                          left: a,
                          width: (b - a).clamp(4, box.maxWidth),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: t.text,
                              borderRadius: DsRadius.pill,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: DsSpace.md),
            Row(
              children: <Widget>[
                figure(
                  length == null ? '–' : IstFormat.hoursMinutes(length),
                  'Worked',
                ),
                const SizedBox(width: 6),
                figure(formatKm(d!.distanceM ?? 0), 'Distance'),
                const SizedBox(width: 6),
                figure('$visits', 'Visits'),
              ],
            ),
            const SizedBox(height: DsSpace.md),
            DsButton(
              label: 'View route of this day',
              icon: DsIcons.route,
              onPressed: () => context.push(Routes.adminDay(d.id)),
            ),
          ] else ...<Widget>[
            Text(
              note,
              style: DsText.label.copyWith(
                color: DsColors.text2,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (d != null &&
                d.userId != null &&
                d.status != DayStatus.onDuty) ...<Widget>[
              const SizedBox(height: DsSpace.md),
              Align(
                alignment: Alignment.centerLeft,
                child: DsButton(
                  label: 'Change day status',
                  icon: DsIcons.edit,
                  kind: DsButtonKind.outline,
                  expand: false,
                  onPressed: () => showChangeDayStatus(context, d),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
