import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_frame.dart';
import '../../duty/domain/duty_day.dart';
import '../application/requests_providers.dart';
import '../data/requests_repository.dart';
import '../domain/app_request.dart';
import '../domain/request_failure.dart';
import 'leave_request_page.dart' show leaveTone;
import 'my_requests_page.dart' show requestKindLook, requestStatusLook;

/// "Request" (design v2): one of the employee's own requests, where it
/// stands, what was sent, and Cancel while it waits.
class MyRequestDetailPage extends ConsumerStatefulWidget {
  const MyRequestDetailPage({required this.requestId, super.key});

  final int requestId;

  @override
  ConsumerState<MyRequestDetailPage> createState() =>
      _MyRequestDetailPageState();
}

class _MyRequestDetailPageState extends ConsumerState<MyRequestDetailPage> {
  bool _cancelling = false;
  String? _error;

  Future<void> _cancel(AppRequest r) async {
    final bool ok = await showDsConfirm(
      context: context,
      title: 'Cancel this request?',
      message: 'The admin will not see it any more.',
      confirm: 'Yes, cancel it',
    );
    if (!ok || !mounted) return;
    setState(() {
      _cancelling = true;
      _error = null;
    });
    try {
      await ref.read(requestsRepositoryProvider).cancel(r.id);
      if (mounted) refreshRequests(ref, r.id);
    } on Object catch (e) {
      if (mounted) setState(() => _error = mapRequestError(e).message);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppRequest?> req = ref.watch(
      requestProvider(widget.requestId),
    );
    final AppRequest? r = req.value;
    return Scaffold(
      backgroundColor: DsColors.surface,
      body: Column(
        children: <Widget>[
          DsScreenHeader(
            title: 'Request',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: req.hasError && r == null
                ? DsErrorState(
                    title: "Couldn't load this request",
                    message: 'Check the internet and try again.',
                    onRetry: () =>
                        ref.invalidate(requestProvider(widget.requestId)),
                  )
                : !req.hasValue
                ? const Center(child: CircularProgressIndicator())
                : r == null
                ? const DsEmptyState(
                    title: 'Request not found',
                    message: 'It may have been removed.',
                    icon: DsIcons.empty,
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.refresh(requestProvider(widget.requestId).future),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        DsSpace.gutter,
                        DsSpace.xs,
                        DsSpace.gutter,
                        DsSpace.xl + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: <Widget>[
                        _TopCard(request: r),
                        const SizedBox(height: 14),
                        _Progress(request: r),
                        const SizedBox(height: 14),
                        _WhatYouSent(request: r),
                        if (_error case final String e) ...<Widget>[
                          const SizedBox(height: 14),
                          DsBanner(kind: DsBannerKind.danger, title: e),
                        ],
                        if (r.cancellable) ...<Widget>[
                          const SizedBox(height: DsSpace.xl),
                          DsButton(
                            label: 'Cancel request',
                            kind: DsButtonKind.dangerSoft,
                            icon: DsIcons.close,
                            busy: _cancelling,
                            busyLabel: 'Cancelling…',
                            onPressed: () => _cancel(r),
                          ),
                          const SizedBox(height: DsSpace.sm),
                          const Text(
                            'You can cancel only while it is waiting.',
                            textAlign: TextAlign.center,
                            style: DsText.caption,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The days of a request: one for attendance and short duty.
List<DateTime> _daysOf(AppRequest r) => r.kind == RequestKind.leave
    ? r.dates
    : <DateTime>[if (r.day != null) r.day!];

/// "Tue 24 – Thu 26 Nov · 3 days", "Fri, 20 Nov".
String requestDaysLine(AppRequest r) {
  final List<DateTime> days = _daysOf(r);
  if (days.isEmpty) return '';
  if (days.length == 1) return IstFormat.weekdayDay(days.first);
  String wd(DateTime d) => IstFormat.weekdayDay(d).split(',').first;
  final DateTime a = days.first;
  final DateTime b = days.last;
  final String range = a.month == b.month
      ? '${wd(a)} ${a.day} – ${wd(b)} ${IstFormat.day(b)}'
      : '${wd(a)} ${IstFormat.day(a)} – ${wd(b)} ${IstFormat.day(b)}';
  // Leave days need not be next to each other.
  final bool together = b.difference(a).inDays == days.length - 1;
  return '${together ? range : '${days.length} days from ${wd(a)} ${IstFormat.day(a)}'}'
      '${together ? ' · ${days.length} days' : ''}';
}

/// The type's colour card: icon, status, title, the days.
class _TopCard extends StatelessWidget {
  const _TopCard({required this.request});

  final AppRequest request;

  @override
  Widget build(BuildContext context) {
    final AppRequest r = request;
    final (IconData icon, DsStatus tone) = requestKindLook(r);
    final (DsStatus pill, String pillLabel) = requestStatusLook(r.status);
    final List<DateTime> days = _daysOf(r);
    final String title = switch (r.kind) {
      RequestKind.leave => r.leaveType?.label ?? 'Leave',
      RequestKind.attendance => 'Attendance',
      RequestKind.shortDuty => 'Short duty',
    };
    final Color dayLabel = r.kind == RequestKind.leave && r.leaveType != null
        ? leaveTone(r.leaveType!).text
        : tone.text;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: tone.tint, borderRadius: DsRadius.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: DsColors.white,
                  borderRadius: DsRadius.medium,
                ),
                child: Icon(icon, size: 22, color: tone.dot),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpace.md,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: DsColors.white,
                  borderRadius: DsRadius.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: pill.dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      pillLabel,
                      style: DsText.label.copyWith(
                        color: pill.text,
                        fontWeight: FontWeight.w700,
                        fontVariations: const <FontVariation>[
                          FontVariation('wght', 700),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(header: true, child: Text(title, style: DsText.title)),
          const SizedBox(height: 2),
          Text(
            requestDaysLine(r),
            style: DsText.body.copyWith(
              color: tone.text,
              fontWeight: FontWeight.w600,
              fontVariations: const <FontVariation>[FontVariation('wght', 600)],
            ),
          ),
          if (days.length > 1) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final DateTime d in days)
                  Container(
                    width: 44,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: DsColors.white,
                      borderRadius: DsRadius.medium,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          IstFormat.weekdayDay(d)
                              .split(',')
                              .first
                              .toUpperCase(),
                          style: DsText.micro.copyWith(color: dayLabel),
                        ),
                        Text('${d.day}', style: DsText.section),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Sent → With admin → Decision, as a vertical line of steps.
class _Progress extends StatelessWidget {
  const _Progress({required this.request});

  final AppRequest request;

  static String _when(DateTime t) =>
      '${IstFormat.shortDate(t)}, ${IstFormat.time(t)}';

  @override
  Widget build(BuildContext context) {
    final AppRequest r = request;
    final bool byApp = r.kind == RequestKind.shortDuty;
    final _Step last = switch (r.status) {
      RequestStatus.pending => const _Step(
        state: _StepState.todo,
        title: 'Decision',
        caption: "You'll get a notification",
      ),
      RequestStatus.approved => _Step(
        state: _StepState.done,
        title: _decisionTitle(r),
        caption: r.decidedAt == null ? null : _when(r.decidedAt!),
        note: r.decisionNote,
        tone: DsStatus.present,
      ),
      RequestStatus.rejected => _Step(
        state: _StepState.stopped,
        title: _decisionTitle(r),
        caption: r.decidedAt == null ? null : _when(r.decidedAt!),
        note: r.decisionNote,
        tone: DsStatus.absent,
      ),
      RequestStatus.cancelled => const _Step(
        state: _StepState.stopped,
        title: 'Cancelled',
        caption: 'You cancelled this request',
        tone: DsStatus.off,
      ),
    };
    final List<_Step> steps = <_Step>[
      _Step(
        state: _StepState.done,
        title: byApp ? 'Sent by the app' : 'Sent',
        side: _when(r.createdAt),
        tone: DsStatus.present,
      ),
      if (r.isPending)
        const _Step(
          state: _StepState.now,
          title: 'With admin',
          side: 'Now',
          caption: 'Usually answered within a day',
        )
      else if (r.status != RequestStatus.cancelled)
        const _Step(
          state: _StepState.done,
          title: 'Seen by admin',
          tone: DsStatus.present,
        ),
      last,
    ];
    return _Card(
      title: 'Progress',
      child: Column(
        children: <Widget>[
          for (int i = 0; i < steps.length; i++)
            _StepRow(step: steps[i], last: i == steps.length - 1),
        ],
      ),
    );
  }

  static String _decisionTitle(AppRequest r) {
    if (r.status == RequestStatus.rejected) return 'Rejected';
    final DayStatus? d = r.decision;
    if (r.kind == RequestKind.leave || d == null) return 'Approved';
    return d == DayStatus.absent ? 'Marked absent' : 'Approved: ${d.label}';
  }
}

enum _StepState { done, now, todo, stopped }

class _Step {
  const _Step({
    required this.state,
    required this.title,
    this.side,
    this.caption,
    this.note,
    this.tone = DsStatus.waiting,
  });

  final _StepState state;
  final String title;

  /// On the right: a time, or "Now".
  final String? side;
  final String? caption;

  /// The admin's note, in a soft box.
  final String? note;
  final DsStatus tone;
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.last});

  final _Step step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final _Step s = step;
    final Widget dot = switch (s.state) {
      _StepState.done => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: s.tone.dot, shape: BoxShape.circle),
        child: const Icon(DsIcons.check, size: 14, color: DsColors.white),
      ),
      _StepState.stopped => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: s.tone.dot, shape: BoxShape.circle),
        child: const Icon(DsIcons.close, size: 14, color: DsColors.white),
      ),
      _StepState.now => Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DsStatus.waiting.tint,
          shape: BoxShape.circle,
          border: Border.all(color: DsStatus.waiting.dot, width: 3),
        ),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: DsStatus.waiting.dot,
            shape: BoxShape.circle,
          ),
        ),
      ),
      _StepState.todo => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: DsColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
        ),
      ),
    };
    final bool muted = s.state == _StepState.todo;
    final String? note = s.note?.trim();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Column(
              children: <Widget>[
                dot,
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: s.state == _StepState.done
                          ? DsStatus.present.dot
                          : DsColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: DsSpace.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: last ? 0 : DsSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          s.title,
                          style: DsText.body.copyWith(
                            color: muted ? DsColors.text2 : DsColors.ink,
                            fontWeight: muted
                                ? FontWeight.w600
                                : FontWeight.w700,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', muted ? 600 : 700),
                            ],
                          ),
                        ),
                      ),
                      if (s.side case final String side)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            side,
                            style: s.state == _StepState.now
                                ? DsText.micro.copyWith(
                                    color: DsStatus.waiting.text,
                                  )
                                : DsText.caption,
                          ),
                        ),
                    ],
                  ),
                  if (s.caption case final String c)
                    Text(c, style: DsText.caption),
                  if (note != null && note.isNotEmpty) ...<Widget>[
                    const SizedBox(height: DsSpace.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DsSpace.md,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: s.tone.tint,
                        borderRadius: DsRadius.medium,
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: <TextSpan>[
                            const TextSpan(
                              text: 'Admin: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontVariations: <FontVariation>[
                                  FontVariation('wght', 700),
                                ],
                              ),
                            ),
                            TextSpan(text: note),
                          ],
                        ),
                        style: DsText.caption.copyWith(
                          color: s.tone.text,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The message, the hours, and the photos.
class _WhatYouSent extends ConsumerWidget {
  const _WhatYouSent({required this.request});

  final AppRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppRequest r = request;
    final List<Widget> rows = <Widget>[];
    void add(Widget w) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(w);
    }

    if (r.dutyOnAt case final DateTime on) {
      add(
        _InfoRow(
          icon: DsIcons.clock,
          title: '${IstFormat.time(on)} – ${IstFormat.time(r.dutyOffAt!)}',
          caption:
              '${IstFormat.hoursMinutes(r.dutyOffAt!.difference(on))} worked',
        ),
      );
    }
    if (r.kind == RequestKind.shortDuty && r.day != null) {
      final DutyDay? d = ref
          .watch(requestDayProvider((r.userId, r.day!)))
          .value;
      if (d != null) {
        add(
          _InfoRow(
            icon: DsIcons.map,
            title: d.dutyOnAt != null && d.dutyOffAt != null
                ? '${IstFormat.time(d.dutyOnAt!)} – ${IstFormat.time(d.dutyOffAt!)}'
                : 'That day',
            caption: d.workedMinutes == null
                ? 'See the route'
                : '${IstFormat.hoursMinutes(Duration(minutes: d.workedMinutes!))}'
                      ' worked · see the route',
            action: 'Route',
            onTap: () => context.push(Routes.userDay(d.id)),
          ),
        );
      }
    }
    if (r.message case final String m when m.trim().isNotEmpty) {
      add(
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: DsColors.surface,
            borderRadius: DsRadius.medium,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(DsIcons.message, size: 18, color: DsColors.text3),
              ),
              const SizedBox(width: DsSpace.md),
              Expanded(
                child: Text(m, style: DsText.body.copyWith(height: 1.5)),
              ),
            ],
          ),
        ),
      );
    }
    if (r.hasPhoto && r.photoRemoved) {
      add(
        const _InfoRow(
          icon: DsIcons.camera,
          title: 'Photo removed after 90 days.',
          caption: 'Photos are kept for 90 days.',
        ),
      );
    } else {
      final String name = r.kind == RequestKind.leave
          ? "Doctor's note"
          : 'Photo of work';
      for (int i = 0; i < r.photoCount; i++) {
        add(
          _InfoRow(
            icon: DsIcons.camera,
            title: name,
            caption: r.photoCount == 1
                ? 'Photo'
                : 'Photo ${i + 1} of ${r.photoCount}',
            action: 'Open',
            onTap: () => openRequestPhoto(context, ref, r.id, i),
          ),
        );
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Card(
      title: r.kind == RequestKind.shortDuty ? 'The day' : 'What you sent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// Opens photo [index] of a request full screen, zoomable.
void openRequestPhoto(
  BuildContext context,
  WidgetRef ref,
  int requestId,
  int index,
) {
  final PhotoSource src = ref
      .read(requestsRepositoryProvider)
      .photo(requestId, index: index);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext context) => Scaffold(
        backgroundColor: DsColors.ink,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: InteractiveViewer(
                child: Center(
                  child: Image.network(
                    src.url,
                    headers: src.headers,
                    fit: BoxFit.contain,
                    semanticLabel: 'Photo ${index + 1}',
                    loadingBuilder: (_, Widget child, ImageChunkEvent? p) =>
                        p == null
                        ? child
                        : const CircularProgressIndicator(
                            color: DsColors.white,
                          ),
                    errorBuilder: (_, _, _) => Text(
                      'The photo could not be loaded.',
                      style: DsText.body.copyWith(color: DsColors.white),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + DsSpace.md,
              left: DsSpace.gutter,
              child: DsIconButton(
                icon: DsIcons.close,
                label: 'Close',
                kind: DsIconButtonKind.glass,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
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
        Semantics(
          header: true,
          child: Text(
            title,
            style: DsText.body.copyWith(
              fontWeight: FontWeight.w700,
              fontVariations: const <FontVariation>[FontVariation('wght', 700)],
            ),
          ),
        ),
        const SizedBox(height: DsSpace.md),
        child,
      ],
    ),
  );
}

/// A grey row: icon tile, title, caption, and an optional white button.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.caption,
    this.action,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String caption;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: '$title, $caption${action == null ? '' : ', $action'}',
    excludeSemantics: true,
    child: Material(
      color: DsColors.surface,
      borderRadius: DsRadius.medium,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.sm),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: DsColors.white,
                  borderRadius: DsRadius.medium,
                ),
                child: Icon(icon, size: 20, color: DsColors.primary),
              ),
              const SizedBox(width: DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        fontVariations: const <FontVariation>[
                          FontVariation('wght', 700),
                        ],
                      ),
                    ),
                    Text(caption, style: DsText.caption),
                  ],
                ),
              ),
              if (action case final String a) ...<Widget>[
                const SizedBox(width: DsSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: DsSpace.sm,
                  ),
                  decoration: const BoxDecoration(
                    color: DsColors.white,
                    borderRadius: DsRadius.pill,
                  ),
                  child: Text(
                    a,
                    style: DsText.label.copyWith(
                      color: DsColors.primary,
                      fontWeight: FontWeight.w700,
                      fontVariations: const <FontVariation>[
                        FontVariation('wght', 700),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
