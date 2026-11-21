import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_field.dart';
import '../../../shared/ds/ds_frame.dart';
import '../application/requests_providers.dart';
import '../data/requests_repository.dart';
import '../domain/app_request.dart';
import '../domain/request_failure.dart';
import 'request_form_parts.dart';

/// The server's limits for one leave request.
const int leaveMaxDays = 31;
const int leaveDaysBack = 7;
const int leaveDaysAhead = 90;

/// The colours of a leave type: Sick rose, Casual purple.
DsStatus leaveTone(LeaveType t) =>
    t == LeaveType.sick ? DsStatus.sick : DsStatus.leave;

/// "Leave request" (design v2): the type, the days on a calendar, the
/// reason, and up to 3 optional photos such as a doctor's note.
class LeaveRequestPage extends ConsumerStatefulWidget {
  const LeaveRequestPage({super.key});

  @override
  ConsumerState<LeaveRequestPage> createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends ConsumerState<LeaveRequestPage> {
  final TextEditingController _message = TextEditingController();
  LeaveType? _type;
  final Set<DateTime> _dates = <DateTime>{};
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

  String _days(int n) => '$n ${n == 1 ? 'day' : 'days'}';

  String? _missing() {
    if (_type == null) return 'Pick the type of leave';
    if (_dates.isEmpty) return 'Pick the days';
    if (_dates.length > leaveMaxDays) return 'At most $leaveMaxDays days';
    if (_message.text.trim().isEmpty) return 'Write the reason to send';
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final RequestsRepository repo = ref.read(requestsRepositoryProvider);
      final List<String> ids = await uploadPhotos(repo, _photos);
      await repo.requestLeave(
        type: _type!,
        dates: _dates.toList()..sort(),
        message: _message.text.trim(),
        proofId: ids.firstOrNull,
        extraPhotoIds: ids.skip(1).toList(),
      );
      if (!mounted) return;
      refreshRequests(ref);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Leave request sent.')));
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) setState(() => _error = mapRequestError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime today = Ist.dateOf(ref.read(serverClockProvider).now());
    final Set<DateTime> waiting = ref.watch(waitingRequestDaysProvider);
    // A day that got a waiting request meanwhile is dropped.
    _dates.removeWhere(waiting.contains);
    final String? missing = _missing();
    final DsStatus tone = leaveTone(_type ?? LeaveType.casual);
    return Scaffold(
      backgroundColor: DsColors.surface,
      body: Column(
        children: <Widget>[
          DsScreenHeader(
            title: 'Leave request',
            subtitle: 'The admin approves or rejects it.',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                DsSpace.gutter,
                DsSpace.xs,
                DsSpace.gutter,
                DsSpace.md,
              ),
              children: <Widget>[
                _StepCard(
                  step: 1,
                  title: 'Type of leave',
                  child: Row(
                    children: <Widget>[
                      for (final LeaveType t in LeaveType.values) ...<Widget>[
                        if (t != LeaveType.values.first)
                          const SizedBox(width: 10),
                        Expanded(
                          child: _TypeTile(
                            type: t,
                            selected: t == _type,
                            onTap: _busy
                                ? null
                                : () => setState(() {
                                    _type = t;
                                    _error = null;
                                  }),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _StepCard(
                  step: 2,
                  title: 'Pick the days',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpace.md,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tone.tint,
                      borderRadius: DsRadius.pill,
                    ),
                    child: Text(
                      _days(_dates.length),
                      style: DsText.label.copyWith(color: tone.text),
                    ),
                  ),
                  child: LeaveCalendar(
                    today: today,
                    selected: _dates,
                    waiting: waiting,
                    color: tone.text,
                    enabled: !_busy,
                    onToggle: (DateTime d) => setState(() {
                      _error = null;
                      if (!_dates.remove(d)) _dates.add(d);
                    }),
                  ),
                ),
                const SizedBox(height: 14),
                _StepCard(
                  step: 3,
                  title: 'Reason',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      DsTextField(
                        label: 'Reason for the leave',
                        controller: _message,
                        locked: _busy,
                        maxLines: 2,
                        maxLength: 500,
                        hint: 'For example: fever, doctor advised rest',
                      ),
                      const SizedBox(height: DsSpace.md),
                      RequestPhotos(
                        photos: _photos,
                        enabled: !_busy,
                        attachLabel: "Doctor's note",
                        onChanged: (List<PickedPhoto> p) =>
                            setState(() => _photos = p),
                      ),
                    ],
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
              DsSpace.lg + MediaQuery.paddingOf(context).bottom,
            ),
            child: DsButton(
              label: missing ?? 'Send request · ${_days(_dates.length)}',
              arrow: missing == null,
              busy: _busy,
              busyLabel: 'Sending…',
              onPressed: missing == null ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// A white card with a numbered title: "1  Type of leave".
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.child,
    this.trailing,
  });

  final int step;
  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
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
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: DsColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$step',
                style: DsText.micro.copyWith(color: DsColors.white),
              ),
            ),
            const SizedBox(width: DsSpace.sm),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: DsText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontVariations: const <FontVariation>[
                      FontVariation('wght', 700),
                    ],
                  ),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: DsSpace.md),
        child,
      ],
    ),
  );
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final LeaveType type;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final DsStatus tone = leaveTone(type);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: type.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? tone.tint : DsColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: DsRadius.large,
          side: selected
              ? BorderSide(color: tone.text, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 96,
            padding: const EdgeInsets.all(14),
            child: Stack(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: DsColors.white,
                        borderRadius: DsRadius.medium,
                      ),
                      child: Icon(
                        type == LeaveType.sick
                            ? DsIcons.sickLeave
                            : DsIcons.casualLeave,
                        size: 20,
                        color: tone.text,
                      ),
                    ),
                    Text(
                      type.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.body.copyWith(
                        color: selected ? tone.text : DsColors.ink,
                        fontWeight: FontWeight.w700,
                        fontVariations: const <FontVariation>[
                          FontVariation('wght', 700),
                        ],
                      ),
                    ),
                  ],
                ),
                if (selected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: tone.text,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        DsIcons.check,
                        size: 14,
                        color: DsColors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A month calendar, Monday first. Tap days on or off. Days outside 7 back
/// to 90 ahead, and days with a request waiting, can't be tapped.
class LeaveCalendar extends StatefulWidget {
  const LeaveCalendar({
    required this.today,
    required this.selected,
    required this.waiting,
    required this.color,
    required this.onToggle,
    this.enabled = true,
    super.key,
  });

  /// IST dates (UTC midnight).
  final DateTime today;
  final Set<DateTime> selected;
  final Set<DateTime> waiting;

  /// The picked days' colour (the leave type's).
  final Color color;
  final ValueChanged<DateTime> onToggle;
  final bool enabled;

  @override
  State<LeaveCalendar> createState() => _LeaveCalendarState();
}

class _LeaveCalendarState extends State<LeaveCalendar> {
  late DateTime _month = DateTime.utc(widget.today.year, widget.today.month);

  static final DateFormat _monthName = DateFormat('MMMM yyyy');
  static final DateFormat _dayName = DateFormat('EEEE, d MMMM');

  DateTime get _first =>
      widget.today.subtract(const Duration(days: leaveDaysBack));
  DateTime get _last => widget.today.add(const Duration(days: leaveDaysAhead));

  bool _canGo(int months) {
    final DateTime m = DateTime.utc(_month.year, _month.month + months);
    final DateTime end = DateTime.utc(m.year, m.month + 1, 0);
    return !end.isBefore(_first) && !m.isAfter(_last);
  }

  @override
  Widget build(BuildContext context) {
    final int lead = _month.weekday - 1; // Monday first
    final int days = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final int rows = ((lead + days) / 7).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            _MonthButton(
              icon: DsIcons.back,
              label: 'Previous month',
              onTap: _canGo(-1)
                  ? () => setState(
                      () =>
                          _month = DateTime.utc(_month.year, _month.month - 1),
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                _monthName.format(_month),
                textAlign: TextAlign.center,
                style: DsText.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontVariations: const <FontVariation>[
                    FontVariation('wght', 700),
                  ],
                ),
              ),
            ),
            _MonthButton(
              icon: DsIcons.forward,
              label: 'Next month',
              onTap: _canGo(1)
                  ? () => setState(
                      () =>
                          _month = DateTime.utc(_month.year, _month.month + 1),
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: DsSpace.md),
        ExcludeSemantics(
          child: Row(
            children: <Widget>[
              for (final String w in const <String>[
                'M',
                'T',
                'W',
                'T',
                'F',
                'S',
                'S',
              ])
                Expanded(
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: DsText.micro.copyWith(color: DsColors.text3),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: DsSpace.xs),
        for (int r = 0; r < rows; r++)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.xs),
            child: Row(
              children: <Widget>[
                for (int c = 0; c < 7; c++)
                  Expanded(child: _cell(r * 7 + c - lead + 1, days)),
              ],
            ),
          ),
        const SizedBox(height: DsSpace.md),
        Row(
          children: <Widget>[
            const Icon(DsIcons.info, size: 14, color: DsColors.text2),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.waiting.isEmpty
                    ? '7 days back to 90 days ahead · up to 31 days'
                    : '7 days back to 90 days ahead · up to 31 days · faded '
                          'days already have a request',
                style: DsText.caption,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cell(int n, int days) {
    if (n < 1 || n > days) return const SizedBox(height: 40);
    final DateTime d = DateTime.utc(_month.year, _month.month, n);
    final bool on = widget.selected.contains(d);
    final bool asked = widget.waiting.contains(d);
    final bool off = d.isBefore(_first) || d.isAfter(_last) || asked;
    final bool isToday = d == widget.today;
    return Center(
      child: Semantics(
        button: true,
        selected: on,
        enabled: !off,
        label:
            '${_dayName.format(d)}${isToday ? ', today' : ''}'
            '${asked ? ', already asked' : ''}',
        excludeSemantics: true,
        child: InkResponse(
          onTap: off || !widget.enabled ? null : () => widget.onToggle(d),
          radius: 22,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? widget.color : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday && !on
                  ? Border.all(color: DsColors.primary, width: 2)
                  : null,
            ),
            child: Text(
              '$n',
              style: DsText.label.copyWith(
                color: on
                    ? DsColors.white
                    : off
                    ? const Color(0xFFCBD5E1)
                    : DsColors.ink,
                decoration: asked ? TextDecoration.lineThrough : null,
                fontWeight: on || isToday ? FontWeight.w700 : FontWeight.w500,
                fontVariations: <FontVariation>[
                  FontVariation('wght', on || isToday ? 700 : 500),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    excludeSemantics: true,
    child: InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.all(7),
        decoration: const BoxDecoration(
          color: DsColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? DsColors.text3 : DsColors.ink,
        ),
      ),
    ),
  );
}
