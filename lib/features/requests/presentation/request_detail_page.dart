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
import '../../../core/links/open_link.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_field.dart';
import '../../duty/domain/duty_day.dart';
import '../../routes/application/route_providers.dart';
import '../../routes/domain/history_month.dart' show fullDay;
import '../../users/application/users_providers.dart';
import '../../users/domain/profile.dart';
import '../application/requests_providers.dart';
import '../data/photo_upload.dart';
import '../domain/app_request.dart';
import 'admin_request_parts.dart';
import 'my_request_detail_page.dart' show openRequestPhoto;
import 'my_requests_page.dart'
    show requestDays, requestKindLook, requestStatusLook;

/// One request, for the admin (design v2, Request detail and Leave
/// detail): who sent it, the facts, photos and reason, the last 30 days,
/// and the decision at the bottom. (The employee's view is
/// MyRequestDetailPage.)
class RequestDetailPage extends ConsumerStatefulWidget {
  const RequestDetailPage({required this.requestId, super.key});

  final int requestId;

  @override
  ConsumerState<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends ConsumerState<RequestDetailPage> {
  final TextEditingController _note = TextEditingController();
  DayStatus? _choice;
  bool _noteOpen = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide(AppRequest r, DayStatus d) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? error = await sendDecision(ref, r, d, note: _note.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Saved: ${decisionLabel(r.kind, d)}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppRequest?> req = ref.watch(
      requestProvider(widget.requestId),
    );
    final AppRequest? r = req.value;
    if (r == null) {
      return Scaffold(
        backgroundColor: DsColors.surface,
        appBar: AppBar(backgroundColor: DsColors.surface),
        body: req.hasError
            ? DsErrorState(
                title: "Couldn't load this request",
                message: 'Check the internet and try again.',
                onRetry: () =>
                    ref.invalidate(requestProvider(widget.requestId)),
              )
            : req.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const DsEmptyState(
                title: 'Request not found',
                message: 'It may have been removed.',
                icon: DsIcons.requests,
              ),
      );
    }
    final Profile? person = ref.watch(userByIdProvider(r.userId)).value;
    final DayStatus choice = _choice ?? r.choices.first;
    return Scaffold(
      backgroundColor: DsColors.surface,
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                _TopBlock(request: r, person: person),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DsSpace.gutter,
                    14,
                    DsSpace.gutter,
                    DsSpace.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (r.kind == RequestKind.leave)
                        _LeaveDays(request: r)
                      else
                        _Facts(request: r),
                      if (r.photoCount > 0 ||
                          (r.message?.trim().isNotEmpty ?? false)) ...<Widget>[
                        const SizedBox(height: DsSpace.md),
                        _PhotosAndReason(request: r),
                      ],
                      if (r.kind != RequestKind.leave) ...<Widget>[
                        const SizedBox(height: DsSpace.md),
                        _Last30Days(request: r),
                      ],
                      if (!r.isPending) ...<Widget>[
                        const SizedBox(height: DsSpace.md),
                        _Decided(request: r),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (r.isPending)
            _DecisionPanel(
              request: r,
              person: person,
              choice: choice,
              onChoice: (DayStatus d) => setState(() => _choice = d),
              noteOpen: _noteOpen,
              onToggleNote: () => setState(() => _noteOpen = !_noteOpen),
              note: _note,
              busy: _busy,
              error: _error,
              onConfirm: () => _decide(r, choice),
            ),
        ],
      ),
    );
  }
}

/// The tinted top: back, "Request", status; call, initials, duty history;
/// the name and "Attendance request · EMP011".
class _TopBlock extends ConsumerWidget {
  const _TopBlock({required this.request, required this.person});

  final AppRequest request;
  final Profile? person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppRequest r = request;
    final Profile? p = person;
    final (IconData icon, DsStatus tone) = requestKindLook(r);
    final (DsStatus statusTone, String statusWord) = requestStatusLook(
      r.status,
    );
    final String? phone = p?.phone?.trim();
    Widget round({
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback? onTap,
    }) => Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: DsColors.white,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 46,
            child: Icon(
              icon,
              size: 20,
              color: onTap == null ? DsColors.text3 : color,
            ),
          ),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: tone.tint,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        DsSpace.gutter,
        MediaQuery.paddingOf(context).top + DsSpace.md,
        DsSpace.gutter,
        22,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              DsIconButton(
                icon: DsIcons.back,
                label: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Text(
                  'Request',
                  textAlign: TextAlign.center,
                  style: DsText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone.text,
                  ),
                ),
              ),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  color: DsColors.white,
                  borderRadius: DsRadius.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusTone.dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusWord,
                      style: DsText.caption.copyWith(
                        color: statusTone.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              round(
                icon: DsIcons.phone,
                label: p == null ? 'Call' : 'Call ${p.fullName}',
                color: DsColors.successText,
                onTap: phone == null || phone.isEmpty
                    ? null
                    : () async {
                        final ScaffoldMessengerState messenger =
                            ScaffoldMessenger.of(context);
                        final bool opened = await ref.read(openLinkProvider)(
                          Uri(scheme: 'tel', path: phone),
                        );
                        if (!opened) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text("Couldn't open the phone app."),
                            ),
                          );
                        }
                      },
              ),
              const SizedBox(width: 18),
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.text,
                  shape: BoxShape.circle,
                  border: Border.all(color: DsColors.white, width: 5),
                ),
                child: Text(
                  p == null ? '' : initialsOf(p.fullName),
                  style: DsText.title.copyWith(color: DsColors.white),
                ),
              ),
              const SizedBox(width: 18),
              round(
                icon: DsIcons.history,
                label: 'Duty history',
                color: tone.text,
                onTap: () => context.push(Routes.adminUserDays(r.userId)),
              ),
            ],
          ),
          const SizedBox(height: DsSpace.md),
          Semantics(
            header: true,
            child: Text(
              p?.fullName ?? ' ',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DsText.title,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: DsColors.white,
              borderRadius: DsRadius.pill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 13, color: tone.text),
                const SizedBox(width: 6),
                Text(
                  <String>[
                    adminRequestKind(r),
                    if (p != null) p.userCode,
                  ].join(' · '),
                  style: DsText.caption.copyWith(
                    color: tone.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
    padding:
        padding ??
        const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: 4),
    decoration: const BoxDecoration(
      color: DsColors.white,
      borderRadius: DsRadius.large,
    ),
    child: child,
  );
}

/// Day, duty times, worked (against 10 h) and when it was sent.
class _Facts extends ConsumerWidget {
  const _Facts({required this.request});

  final AppRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppRequest r = request;
    // A short duty's times come from the day itself.
    final DutyDay? day = r.kind == RequestKind.shortDuty && r.day != null
        ? ref.watch(requestDayProvider((r.userId, r.day!))).value
        : null;
    final DateTime? on = r.dutyOnAt ?? day?.dutyOnAt;
    final DateTime? off = r.dutyOffAt ?? day?.dutyOffAt;
    final Duration? worked = day?.workedMinutes != null
        ? Duration(minutes: day!.workedMinutes!)
        : on != null && off != null
        ? off.difference(on)
        : null;
    final bool met = worked != null && worked >= fullDay;
    final List<(String, Widget)> rows = <(String, Widget)>[
      if (r.day case final DateTime d)
        ('Day', _value(DateFormat('EEE, d MMM yyyy').format(d))),
      if (on != null && off != null)
        (
          'Duty times',
          _value('${IstFormat.time(on)} → ${IstFormat.time(off)}'),
        ),
      if (worked != null)
        (
          'Worked',
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              _value(IstFormat.hoursMinutes(worked)),
              DsStatusPill(
                status: met ? DsStatus.present : DsStatus.waiting,
                label: met ? '✓ 10h met' : 'Under 10h',
              ),
            ],
          ),
        ),
      (
        'Sent',
        _value(_sent(r.createdAt, ref.watch(serverClockProvider).now())),
      ),
    ];
    return _Card(
      child: Column(
        children: <Widget>[
          for (final (int i, (String label, Widget value)) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: i == rows.length - 1 && day == null
                  ? null
                  : const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFEEF2F6)),
                      ),
                    ),
              child: Row(
                children: <Widget>[
                  Text(
                    label,
                    style: DsText.body.copyWith(color: DsColors.text2),
                  ),
                  const SizedBox(width: DsSpace.md),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: value,
                    ),
                  ),
                ],
              ),
            ),
          if (day != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DsTextLink(
                  label: 'View route',
                  onPressed: () => context.push(Routes.adminDay(day.id)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _value(String text) => Text(
    text,
    textAlign: TextAlign.right,
    style: DsText.body.copyWith(fontWeight: FontWeight.w700),
  );
}

/// "Today, 8:47 AM", "Yesterday, 6:15 PM", "18 Nov, 9:05 AM".
/// With [lower], "today, 8:47 AM" for the middle of a sentence.
String _sent(DateTime t, DateTime now, {bool lower = false}) {
  final int days = Ist.dateOf(now).difference(Ist.dateOf(t)).inDays;
  final String day = days <= 0
      ? (lower ? 'today' : 'Today')
      : days == 1
      ? (lower ? 'yesterday' : 'Yesterday')
      : IstFormat.shortDate(t);
  return '$day, ${IstFormat.time(t)}';
}

/// Leave: the weeks with the leave days filled, the number of days, and
/// when it was sent.
class _LeaveDays extends ConsumerWidget {
  const _LeaveDays({required this.request});

  final AppRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppRequest r = request;
    final Set<DateTime> leave = r.dates.toSet();
    final DateTime now = ref.watch(serverClockProvider).now();
    final DateTime today = Ist.dateOf(now);
    final DateTime first = r.dates.first;
    final DateTime last = r.dates.last;
    final DateTime monday = first.subtract(Duration(days: first.weekday - 1));
    final DateTime sunday = last.add(Duration(days: 7 - last.weekday));
    final int weeks = (sunday.difference(monday).inDays + 1) ~/ 7;
    final int startsIn = first.difference(today).inDays;
    final String starts = startsIn > 1
        ? 'starts in $startsIn days'
        : startsIn == 1
        ? 'starts tomorrow'
        : startsIn == 0
        ? 'starts today'
        : 'started ${-startsIn} ${startsIn == -1 ? 'day' : 'days'} ago';
    final int n = r.dates.length;
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  requestDays(r),
                  style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              DsStatusPill(
                status: DsStatus.leave,
                label: '$n ${n == 1 ? 'day' : 'days'}',
              ),
            ],
          ),
          const SizedBox(height: DsSpace.md),
          Semantics(
            label: 'Leave on ${r.dates.map(IstFormat.weekdayDay).join(', ')}',
            excludeSemantics: true,
            child: Column(
              children: <Widget>[
                for (int w = 0; w < weeks; w++) ...<Widget>[
                  if (w > 0) const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < 7; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _DayBox(
                            date: monday.add(Duration(days: w * 7 + i)),
                            on: leave.contains(
                              monday.add(Duration(days: w * 7 + i)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: DsSpace.md),
          Text(
            'Sent ${_sent(r.createdAt, now, lower: true)} · $starts',
            style: DsText.caption,
          ),
        ],
      ),
    );
  }
}

class _DayBox extends StatelessWidget {
  const _DayBox({required this.date, required this.on});

  final DateTime date;
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    decoration: BoxDecoration(
      color: on ? DsStatus.leave.text : DsColors.surface,
      borderRadius: DsRadius.medium,
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          DateFormat('EEE').format(date).toUpperCase(),
          style: DsText.micro.copyWith(
            fontWeight: FontWeight.w700,
            color: on ? DsColors.white : DsColors.text2,
          ),
        ),
        Text(
          '${date.day}',
          style: DsText.section.copyWith(
            color: on ? DsColors.white : DsColors.text2,
          ),
        ),
      ],
    ),
  );
}

/// The photos one at a time (tap for full size) and the reason.
class _PhotosAndReason extends ConsumerStatefulWidget {
  const _PhotosAndReason({required this.request});

  final AppRequest request;

  @override
  ConsumerState<_PhotosAndReason> createState() => _PhotosAndReasonState();
}

class _PhotosAndReasonState extends ConsumerState<_PhotosAndReason> {
  final PageController _pages = PageController();
  int _at = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) => _pages.animateToPage(
    i,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final AppRequest r = widget.request;
    final int count = r.photoCount;
    final String? m = r.message?.trim();
    final String what = r.kind == RequestKind.leave ? 'proof' : 'photo';
    return _Card(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (count > 0 && r.photoRemoved)
            Container(
              height: 80,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: DsColors.surface,
                borderRadius: DsRadius.medium,
              ),
              child: Text(
                'Photo removed after 90 days.',
                style: DsText.body.copyWith(color: DsColors.text2),
              ),
            )
          else if (count > 0)
            ClipRRect(
              borderRadius: DsRadius.medium,
              child: SizedBox(
                height: 220,
                child: Stack(
                  children: <Widget>[
                    PageView(
                      controller: _pages,
                      onPageChanged: (int i) => setState(() => _at = i),
                      children: <Widget>[
                        for (int i = 0; i < count; i++)
                          Semantics(
                            button: true,
                            label: 'Open $what ${i + 1} of $count full size',
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: () =>
                                  openRequestPhoto(context, ref, r.id, i),
                              child: _Photo(
                                source: ref
                                    .watch(requestsRepositoryProvider)
                                    .photo(r.id, index: i),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xB80F172A),
                          borderRadius: DsRadius.pill,
                        ),
                        child: Text(
                          '${_at + 1} / $count',
                          style: DsText.caption.copyWith(
                            color: DsColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (count > 1) ...<Widget>[
                      Positioned(
                        left: 10,
                        top: 90,
                        child: _Arrow(
                          icon: DsIcons.back,
                          label: 'Previous photo',
                          onTap: _at == 0 ? null : () => _go(_at - 1),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 90,
                        child: _Arrow(
                          icon: DsIcons.forward,
                          label: 'Next photo',
                          onTap: _at == count - 1 ? null : () => _go(_at + 1),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            for (int i = 0; i < count; i++)
                              Container(
                                width: i == _at ? 18 : 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: i == _at
                                      ? DsColors.white
                                      : const Color(0x99FFFFFF),
                                  borderRadius: DsRadius.pill,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (m != null && m.isNotEmpty) ...<Widget>[
            if (count > 0) const SizedBox(height: DsSpace.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'REASON',
                    style: DsText.micro.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: DsColors.text2,
                    ),
                  ),
                  const SizedBox(height: DsSpace.xs),
                  Text(m, style: DsText.body.copyWith(height: 1.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.source});

  final PhotoSource source;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFCBD5E1),
    child: Image.network(
      source.url,
      headers: source.headers,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, _, _) => Center(
        child: Text(
          'The photo could not be loaded.',
          style: DsText.caption.copyWith(color: const Color(0xFF475569)),
        ),
      ),
      loadingBuilder: (_, Widget child, ImageChunkEvent? p) =>
          p == null ? child : const Center(child: CircularProgressIndicator()),
    ),
  );
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: DsColors.white,
      shape: const CircleBorder(),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 40,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? const Color(0xFFCBD5E1) : DsColors.ink,
          ),
        ),
      ),
    ),
  );
}

/// A square per day of the last 30, coloured by status; this request's
/// day has a ring.
class _Last30Days extends ConsumerWidget {
  const _Last30Days({required this.request});

  final AppRequest request;

  static const Color _present = DsColors.primary;
  static const Color _half = Color(0xFF7DD3FC);
  static const Color _absent = Color(0xFFF87171);
  static const Color _none = Color(0xFFE2E8F0);
  static const Color _this = Color(0xFFF59E0B);

  static Color _colour(DayStatus? s) => switch (s) {
    DayStatus.present || DayStatus.onDuty => _present,
    DayStatus.halfDay => _half,
    DayStatus.absent => _absent,
    DayStatus.leave => DsStatus.leave.dot,
    DayStatus.pending => _this,
    null => _none,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppRequest r = request;
    final DateTime today = Ist.dateOf(ref.watch(serverClockProvider).now());
    final List<DutyDay> history =
        ref.watch(historyProvider(r.userId)).value ?? const <DutyDay>[];
    final Map<DateTime, DayStatus> byDay = <DateTime, DayStatus>{
      for (final DutyDay d in history) d.day: d.status,
    };
    final List<DateTime> days = <DateTime>[
      for (int i = 29; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    int count(DayStatus s) => days.where((DateTime d) => byDay[d] == s).length;
    Widget key(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: DsText.micro.copyWith(color: DsColors.text2)),
      ],
    );
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Last 30 days',
                    style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  '${count(DayStatus.present)} present · '
                  '${count(DayStatus.halfDay)} half · '
                  '${count(DayStatus.absent)} absent',
                  textAlign: TextAlign.right,
                  style: DsText.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ExcludeSemantics(
            child: Column(
              children: <Widget>[
                for (int row = 0; row < 2; row++) ...<Widget>[
                  if (row > 0) const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < 15; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: days[row * 15 + i] == r.day
                                  ? _this
                                  : _colour(byDay[days[row * 15 + i]]),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: days[row * 15 + i] == r.day
                                  ? const <BoxShadow>[
                                      BoxShadow(
                                        color: DsColors.white,
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(color: _this, spreadRadius: 3),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: <Widget>[
              key(_present, 'Present'),
              key(_half, 'Half'),
              key(_absent, 'Absent'),
              key(DsStatus.leave.dot, 'Leave'),
              key(_none, 'No duty'),
              key(_this, 'This request'),
            ],
          ),
        ],
      ),
    );
  }
}

/// A decided request: the outcome, when, and the admin's note.
class _Decided extends StatelessWidget {
  const _Decided({required this.request});

  final AppRequest request;

  @override
  Widget build(BuildContext context) {
    final AppRequest r = request;
    final (DsStatus tone, String _) = requestStatusLook(r.status);
    return _Card(
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Decision',
                    style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              DsStatusPill(status: tone, label: requestOutcome(r)),
            ],
          ),
          if (r.decidedAt case final DateTime t) ...<Widget>[
            const SizedBox(height: DsSpace.xs),
            Text(
              'Decided ${IstFormat.date(Ist.dateOf(t))}, ${IstFormat.time(t)}',
              style: DsText.caption,
            ),
          ],
          if (r.decisionNote case final String n
              when n.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: DsSpace.sm),
            Text('Note: $n', style: DsText.body),
          ],
        ],
      ),
    );
  }
}

/// "Your decision": the choices, an optional note and the confirm button,
/// pinned at the bottom while the request waits.
class _DecisionPanel extends StatelessWidget {
  const _DecisionPanel({
    required this.request,
    required this.person,
    required this.choice,
    required this.onChoice,
    required this.noteOpen,
    required this.onToggleNote,
    required this.note,
    required this.busy,
    required this.error,
    required this.onConfirm,
  });

  final AppRequest request;
  final Profile? person;
  final DayStatus choice;
  final ValueChanged<DayStatus> onChoice;
  final bool noteOpen;
  final VoidCallback onToggleNote;
  final TextEditingController note;
  final bool busy;
  final String? error;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final AppRequest r = request;
    final String first = person == null
        ? ''
        : person!.fullName.trim().split(RegExp(r'\s+')).first;
    final bool leave = r.kind == RequestKind.leave;
    final int n = r.dates.length;
    final String confirm = switch (choice) {
      DayStatus.absent when leave => 'Reject leave request',
      DayStatus.absent when r.kind == RequestKind.attendance =>
        'Reject request',
      DayStatus.absent => 'Confirm · Absent',
      DayStatus.leave =>
        'Approve $n ${n == 1 ? 'day' : 'days'} '
            '${(r.leaveType?.label ?? 'leave').toLowerCase()}',
      _ => 'Confirm · ${decisionLabel(r.kind, choice)}',
    };
    final String? help = !leave
        ? null
        : choice == DayStatus.leave
        ? 'The ${n == 1 ? 'day is' : '$n days are'} marked as '
              '${(r.leaveType?.label ?? 'leave').toLowerCase()}.'
              '${first.isEmpty ? '' : ' $first gets a notification.'}'
        : 'The days stay as normal duty days.'
              '${first.isEmpty ? '' : ' $first gets a notification.'}';
    return Container(
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.sheetTop,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        DsSpace.gutter,
        DsSpace.lg,
        DsSpace.gutter,
        DsSpace.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: const Text('Your decision', style: DsText.section),
                ),
              ),
              Semantics(
                button: true,
                label: noteOpen ? 'Hide note' : 'Add note',
                excludeSemantics: true,
                child: Material(
                  color: const Color(0xFFEEF2F6),
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: busy ? null : onToggleNote,
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            noteOpen ? DsIcons.close : DsIcons.add,
                            size: 14,
                            color: DsColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            noteOpen ? 'Hide note' : 'Add note',
                            style: DsText.caption.copyWith(
                              color: DsColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpace.md),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2F6),
              borderRadius: DsRadius.large,
            ),
            child: Row(
              children: <Widget>[
                for (final (int i, DayStatus d)
                    in r.choices.indexed) ...<Widget>[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: d == choice,
                      label: decisionLabel(r.kind, d),
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: busy ? null : () => onChoice(d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: d == choice
                                ? decisionColor(r.kind, d)
                                : Colors.transparent,
                            borderRadius: DsRadius.medium,
                            boxShadow: d == choice ? DsShadow.card : null,
                          ),
                          child: Text(
                            decisionLabel(r.kind, d),
                            style: DsText.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: d == choice
                                  ? DsColors.white
                                  : d == DayStatus.absent
                                  ? DsColors.dangerText
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (noteOpen) ...<Widget>[
            const SizedBox(height: DsSpace.md),
            DsTextField(
              label: first.isEmpty ? 'Note' : 'Note to $first',
              optional: true,
              controller: note,
              hint: leave
                  ? 'For example: get well soon'
                  : 'For example: remember duty on',
              maxLength: 300,
            ),
          ],
          if (error case final String e) ...<Widget>[
            const SizedBox(height: DsSpace.sm),
            Text(e, style: DsText.body.copyWith(color: DsColors.dangerText)),
          ],
          const SizedBox(height: DsSpace.md),
          _ConfirmButton(
            label: confirm,
            color: decisionColor(r.kind, choice),
            busy: busy,
            onPressed: onConfirm,
          ),
          if (help != null) ...<Widget>[
            const SizedBox(height: DsSpace.sm),
            Text(help, textAlign: TextAlign.center, style: DsText.caption),
          ],
        ],
      ),
    );
  }
}

/// The big round button in the decision's colour.
class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.label,
    required this.color,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: !busy,
    label: busy ? 'Saving' : label,
    excludeSemantics: true,
    child: Material(
      color: color,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onPressed,
        child: SizedBox(
          height: 56,
          child: Center(
            child: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: DsColors.white,
                    ),
                  )
                : Text(
                    label,
                    style: DsText.body.copyWith(
                      color: DsColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}
