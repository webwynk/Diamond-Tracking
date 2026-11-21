import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/rules/duty_rules.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_field.dart';
import '../application/requests_providers.dart';
import '../data/requests_repository.dart';
import '../domain/request_failure.dart';
import 'request_form_parts.dart';

/// Days the form offers: today and the 7 before (the server's window).
const int attendanceWindowDays = 8;

/// "Request attendance" (design v2). Forgot duty on: pick the day, the
/// times worked, tell the admin why, and add up to 3 photos.
class AttendanceRequestPage extends ConsumerStatefulWidget {
  const AttendanceRequestPage({super.key});

  @override
  ConsumerState<AttendanceRequestPage> createState() =>
      _AttendanceRequestPageState();
}

class _AttendanceRequestPageState extends ConsumerState<AttendanceRequestPage> {
  final TextEditingController _message = TextEditingController();

  /// The IST date picked; null until the employee picks one when today
  /// can't be asked for.
  DateTime? _day;
  bool _dayTouched = false;
  int? _on; // minutes since midnight
  int? _off;
  List<PickedPhoto> _photos = <PickedPhoto>[];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  DateTime get _now => ref.read(serverClockProvider).now();

  List<DateTime> _window() {
    final DateTime today = Ist.dateOf(_now);
    return <DateTime>[
      for (int i = attendanceWindowDays - 1; i >= 0; i--)
        today.subtract(Duration(days: i)),
    ];
  }

  Future<void> _pickTime({required bool on}) async {
    final int? current = on ? _on : _off;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay(hour: on ? 9 : 19, minute: 0)
          : TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: on ? 'Duty on time' : 'Duty off time',
    );
    if (picked == null) return;
    setState(() {
      _error = null;
      if (on) {
        _on = picked.hour * 60 + picked.minute;
      } else {
        _off = picked.hour * 60 + picked.minute;
      }
    });
  }

  /// What is still missing, as the button says it; null when ready.
  String? _missing(DateTime? day) {
    if (day == null) return 'Pick a day';
    if (_on == null || _off == null) return 'Pick the duty times';
    if (_off! <= _on!) return 'Duty off must be after duty on';
    if (day == Ist.dateOf(_now) && _off! > Ist.minuteOfDay(_now)) {
      return 'Duty off is later than now';
    }
    if (_message.text.trim().isEmpty) return 'Write a message to send';
    if (_photos.isEmpty) return 'Add a photo to send';
    return null;
  }

  Future<void> _submit(DateTime day) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final RequestsRepository repo = ref.read(requestsRepositoryProvider);
      final List<String> ids = await uploadPhotos(repo, _photos);
      await repo.requestAttendance(
        day: day,
        dutyOnMinute: _on!,
        dutyOffMinute: _off!,
        message: _message.text.trim(),
        photoId: ids.first,
        extraPhotoIds: ids.skip(1).toList(),
      );
      if (!mounted) return;
      refreshRequests(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent. The admin will decide.')),
      );
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) setState(() => _error = mapRequestError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<DateTime, BlockedDay> blocked = ref.watch(
      attendanceBlockedDaysProvider,
    );
    final List<DateTime> window = _window();
    // Until the employee picks, the newest day that can still be asked for.
    DateTime? day = _day;
    if (!_dayTouched || (day != null && blocked.containsKey(day))) {
      day = null;
      for (final DateTime d in window.reversed) {
        if (!blocked.containsKey(d)) {
          day = d;
          break;
        }
      }
    }
    final String? missing = _missing(day);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: DsColors.deep,
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              DsSpace.gutter,
              safe.top + DsSpace.md,
              DsSpace.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    DsIconButton(
                      icon: DsIcons.back,
                      label: 'Back',
                      kind: DsIconButtonKind.glass,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: DsSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Semantics(
                            header: true,
                            child: Text(
                              'Request attendance',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: DsText.title.copyWith(
                                color: DsColors.white,
                              ),
                            ),
                          ),
                          Text(
                            'Forgot duty on? Pick the day you worked.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DsText.caption.copyWith(
                              color: DsColors.skyText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _DayStrip(
                  days: window,
                  today: window.last,
                  picked: day,
                  blocked: blocked,
                  enabled: !_busy,
                  onPick: (DateTime d) => setState(() {
                    _day = d;
                    _dayTouched = true;
                    _error = null;
                  }),
                ),
                const SizedBox(height: DsSpace.sm),
                Text(
                  blocked.keys.any(window.contains)
                      ? 'Faded days already have a duty or a request.'
                      : 'Today or up to 7 days back.',
                  textAlign: TextAlign.center,
                  style: DsText.caption.copyWith(color: DsColors.skyText),
                ),
                const SizedBox(height: DsSpace.lg),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: DsColors.surface,
                borderRadius: DsRadius.sheetTop,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        DsSpace.gutter,
                        18,
                        DsSpace.gutter,
                        DsSpace.md,
                      ),
                      children: <Widget>[
                        if (day == null)
                          const DsBanner(
                            kind: DsBannerKind.info,
                            title: 'No day left to ask for',
                            message:
                                'Every day in the last week already has a duty '
                                'or a request.',
                          )
                        else
                          _HoursCard(
                            day: day,
                            on: _on,
                            off: _off,
                            enabled: !_busy,
                            onPick: (bool on) => _pickTime(on: on),
                          ),
                        const SizedBox(height: DsSpace.md),
                        RequestSection(
                          title: 'Tell the admin',
                          child: DsTextField(
                            label: 'Message',
                            controller: _message,
                            locked: _busy,
                            maxLines: 3,
                            maxLength: 500,
                            hint:
                                'Why there was no duty on, and what you did '
                                'that day',
                          ),
                        ),
                        const SizedBox(height: DsSpace.md),
                        RequestSection(
                          title: 'Photos of your work',
                          trailing: const DsTag(
                            label: 'Required',
                            status: DsStatus.waiting,
                          ),
                          child: RequestPhotos(
                            photos: _photos,
                            enabled: !_busy,
                            onChanged: (List<PickedPhoto> p) => setState(() {
                              _photos = p;
                              _error = null;
                            }),
                          ),
                        ),
                        if (_error case final String e) ...<Widget>[
                          const SizedBox(height: DsSpace.md),
                          DsBanner(kind: DsBannerKind.danger, title: e),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      DsSpace.gutter,
                      DsSpace.sm,
                      DsSpace.gutter,
                      DsSpace.lg + safe.bottom,
                    ),
                    child: DsButton(
                      label: missing ?? 'Send request',
                      arrow: missing == null,
                      busy: _busy,
                      busyLabel: 'Sending…',
                      onPressed: missing == null ? () => _submit(day!) : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eight round day buttons: weekday and date. The picked one is white,
/// faded ones can't be asked for.
class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.days,
    required this.today,
    required this.picked,
    required this.blocked,
    required this.enabled,
    required this.onPick,
  });

  final List<DateTime> days;
  final DateTime today;
  final DateTime? picked;
  final Map<DateTime, BlockedDay> blocked;
  final bool enabled;
  final ValueChanged<DateTime> onPick;

  static const List<String> _weekdays = <String>[
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      for (int i = 0; i < days.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(width: 5),
        Expanded(child: _dayButton(days[i])),
      ],
    ],
  );

  Widget _dayButton(DateTime d) {
    final bool on = d == picked;
    final BlockedDay? why = blocked[d];
    final bool isToday = d == today;
    final String reason = switch (why) {
      BlockedDay.hadDuty => ', already has a duty',
      BlockedDay.asked => ', already asked',
      null => '',
    };
    final Color fg = on ? DsColors.deep : DsColors.white;
    return Semantics(
      button: true,
      selected: on,
      enabled: why == null,
      label: '${IstFormat.dayDate(d)}${isToday ? ', today' : ''}$reason',
      excludeSemantics: true,
      child: Opacity(
        opacity: why == null ? 1 : 0.35,
        child: Material(
          color: on ? DsColors.white : DsColors.deepRaised,
          borderRadius: DsRadius.large,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled && why == null ? () => onPick(d) : null,
            child: SizedBox(
              height: 66,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isToday ? 'TODAY' : _weekdays[d.weekday - 1],
                      style: DsText.micro.copyWith(
                        color: fg.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text('${d.day}', style: DsText.section.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The picked day, Duty on and Duty off times, the hours between them and
/// one bar per hour of the 10 hour day.
class _HoursCard extends StatelessWidget {
  const _HoursCard({
    required this.day,
    required this.on,
    required this.off,
    required this.enabled,
    required this.onPick,
  });

  final DateTime day;
  final int? on;
  final int? off;
  final bool enabled;
  final ValueChanged<bool> onPick;

  static String _time(int? m) {
    if (m == null) return 'Pick';
    final DateTime t = DateTime.utc(2000, 1, 1, m ~/ 60, m % 60);
    return IstFormat.time(t.subtract(Ist.offset));
  }

  @override
  Widget build(BuildContext context) {
    final int? worked = on != null && off != null && off! > on!
        ? off! - on!
        : null;
    final int goal = DutyRules.minimumDuty.inMinutes;
    final bool full = worked != null && worked >= goal;
    final int hours = DutyRules.minimumDuty.inHours;
    final int filled = worked == null ? 0 : (worked ~/ 60).clamp(0, hours);
    return RequestSection(
      title: IstFormat.dayDate(day),
      trailing: worked == null
          ? null
          : DsTag(
              label: full
                  ? 'Full day'
                  : 'Under ${DutyRules.minimumDuty.inHours} h',
              status: full ? DsStatus.present : DsStatus.waiting,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TimeButton(
                      label: 'DUTY ON',
                      labelColor: DsStatus.present.text,
                      time: _time(on),
                      start: true,
                      onTap: enabled ? () => onPick(true) : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _TimeButton(
                      label: 'DUTY OFF',
                      labelColor: DsColors.text2,
                      time: _time(off),
                      start: false,
                      onTap: enabled ? () => onPick(false) : null,
                    ),
                  ),
                ],
              ),
              if (worked != null)
                IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DsColors.ink,
                      borderRadius: DsRadius.pill,
                      border: Border.all(color: DsColors.white, width: 3),
                    ),
                    child: Text(
                      IstFormat.hoursMinutes(Duration(minutes: worked)),
                      style: DsText.micro.copyWith(color: DsColors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DsSpace.md),
          ExcludeSemantics(
            child: Row(
              children: <Widget>[
                for (int i = 0; i < hours; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < filled
                            ? (full
                                  ? DsStatus.present.dot
                                  : DsStatus.waiting.dot)
                            : DsColors.line,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.labelColor,
    required this.time,
    required this.start,
    required this.onTap,
  });

  final String label;
  final Color labelColor;
  final String time;

  /// Left button (rounder on the left) or right.
  final bool start;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const Radius big = Radius.circular(24);
    const Radius small = Radius.circular(16);
    return Semantics(
      button: true,
      label: '${label.toLowerCase()}, $time',
      excludeSemantics: true,
      child: Material(
        color: DsColors.surface,
        borderRadius: BorderRadius.horizontal(
          left: start ? big : small,
          right: start ? small : big,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
            alignment: start ? Alignment.centerLeft : Alignment.centerRight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: start
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: <Widget>[
                Text(label, style: DsText.micro.copyWith(color: labelColor)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(time, style: DsText.value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
