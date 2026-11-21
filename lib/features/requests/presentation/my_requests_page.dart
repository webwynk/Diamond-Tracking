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
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_frame.dart';
import '../../duty/domain/duty_day.dart';
import '../application/requests_providers.dart';
import '../domain/app_request.dart';

/// The list filters on "My requests".
enum MyRequestsFilter {
  all('All', null),
  waiting('Waiting', RequestStatus.pending),
  approved('Approved', RequestStatus.approved),
  rejected('Rejected', RequestStatus.rejected);

  const MyRequestsFilter(this.label, this.status);

  final String label;

  /// Null shows every request, cancelled ones too.
  final RequestStatus? status;

  bool matches(AppRequest r) => status == null || r.status == status;
}

/// "My requests" (design v2): two tiles for new requests, then everything
/// sent in the last 90 days with a filter.
class MyRequestsPage extends ConsumerStatefulWidget {
  const MyRequestsPage({super.key});

  @override
  ConsumerState<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends ConsumerState<MyRequestsPage> {
  MyRequestsFilter _filter = MyRequestsFilter.all;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppRequest>> list = ref.watch(myRequestsProvider);
    final List<AppRequest> all = list.value ?? const <AppRequest>[];
    final List<AppRequest> shown = all.where(_filter.matches).toList();
    return Scaffold(
      backgroundColor: DsColors.surface,
      body: Column(
        children: <Widget>[
          DsScreenHeader(
            title: 'My requests',
            subtitle: 'Ask the admin for attendance or leave',
            onBack: context.canPop() ? () => context.pop() : null,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(myRequestsProvider.future),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  DsSpace.gutter,
                  DsSpace.xs,
                  DsSpace.gutter,
                  DsSpace.xl + MediaQuery.paddingOf(context).bottom,
                ),
                children: <Widget>[
                  const _NewRequestTiles(),
                  const SizedBox(height: DsSpace.xl),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: DsSpace.xs),
                    child: Row(
                      children: <Widget>[
                        Expanded(child: Text('Sent', style: DsText.section)),
                        Text('Last 90 days', style: DsText.caption),
                      ],
                    ),
                  ),
                  const SizedBox(height: DsSpace.xs),
                  if (list.hasError && !list.hasValue)
                    DsErrorState(
                      title: "Couldn't load your requests",
                      message: 'Check the internet and try again.',
                      onRetry: () => ref.invalidate(myRequestsProvider),
                    )
                  else if (!list.hasValue)
                    const Padding(
                      padding: EdgeInsets.all(DsSpace.xxl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (all.isEmpty)
                    const DsEmptyState(
                      title: 'No requests yet',
                      message: 'Requests you send show here with the decision.',
                      icon: DsIcons.empty,
                    )
                  else ...<Widget>[
                    _Filters(
                      all: all,
                      selected: _filter,
                      onSelect: (MyRequestsFilter f) =>
                          setState(() => _filter = f),
                    ),
                    const SizedBox(height: DsSpace.sm),
                    if (shown.isEmpty)
                      DsEmptyState(
                        title: 'No ${_filter.label.toLowerCase()} requests',
                        icon: DsIcons.empty,
                      ),
                    for (final AppRequest r in shown) ...<Widget>[
                      MyRequestCard(
                        request: r,
                        onTap: () => context.push(Routes.userRequest(r.id)),
                      ),
                      const SizedBox(height: 10),
                    ],
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

/// Attendance (brand blue) and Leave (violet), side by side.
class _NewRequestTiles extends StatelessWidget {
  const _NewRequestTiles();

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: _NewTile(
          icon: DsIcons.attendance,
          title: 'Attendance',
          caption: 'Forgot duty on',
          background: DsColors.primary,
          foreground: DsColors.white,
          captionColor: const Color(0xFFD5E9F1),
          iconBackground: const Color(0xFF1C7CA3),
          iconColor: DsColors.white,
          plusBackground: DsColors.white,
          plusColor: DsColors.primary,
          shadow: DsShadow.button,
          onTap: () => context.push(Routes.userRequestAttendance),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _NewTile(
          icon: DsIcons.history,
          title: 'Leave',
          caption: 'Sick or casual',
          background: DsStatus.leave.tint,
          foreground: const Color(0xFF4C1D95),
          captionColor: DsStatus.leave.text,
          iconBackground: DsColors.white,
          iconColor: DsStatus.leave.text,
          plusBackground: DsStatus.leave.text,
          plusColor: DsColors.white,
          onTap: () => context.push(Routes.userRequestLeave),
        ),
      ),
    ],
  );
}

class _NewTile extends StatelessWidget {
  const _NewTile({
    required this.icon,
    required this.title,
    required this.caption,
    required this.background,
    required this.foreground,
    required this.captionColor,
    required this.iconBackground,
    required this.iconColor,
    required this.plusBackground,
    required this.plusColor,
    required this.onTap,
    this.shadow,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Color background;
  final Color foreground;
  final Color captionColor;
  final Color iconBackground;
  final Color iconColor;
  final Color plusBackground;
  final Color plusColor;
  final List<BoxShadow>? shadow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'New $title request, $caption',
    excludeSemantics: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: DsRadius.large,
        boxShadow: shadow,
      ),
      child: Material(
        color: background,
        borderRadius: DsRadius.large,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 132,
            padding: const EdgeInsets.all(DsSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: DsRadius.medium,
                      ),
                      child: Icon(icon, size: 20, color: iconColor),
                    ),
                    const Spacer(),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: plusBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(DsIcons.add, size: 16, color: plusColor),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.section.copyWith(color: foreground),
                    ),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.caption.copyWith(color: captionColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// All / Waiting / Approved / Rejected with counts, swipeable on narrow
/// phones.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.all,
    required this.selected,
    required this.onSelect,
  });

  final List<AppRequest> all;
  final MyRequestsFilter selected;
  final ValueChanged<MyRequestsFilter> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    child: Row(
      children: <Widget>[
        for (final MyRequestsFilter f in MyRequestsFilter.values) ...<Widget>[
          if (f != MyRequestsFilter.all) const SizedBox(width: DsSpace.sm),
          DsFilterChip(
            label: f.label,
            selected: f == selected,
            count: all.where(f.matches).length,
            dot: switch (f) {
              MyRequestsFilter.all => null,
              MyRequestsFilter.waiting => DsStatus.waiting.dot,
              MyRequestsFilter.approved => DsStatus.present.dot,
              MyRequestsFilter.rejected => DsStatus.absent.dot,
            },
            onTap: () => onSelect(f),
          ),
        ],
      ],
    ),
  );
}

/// "Fri, 20 Nov" for one day; "24 – 26 Nov" or "30 Nov – 2 Dec" for leave.
String requestDays(AppRequest r) {
  if (r.kind != RequestKind.leave) return IstFormat.day(r.day!);
  if (r.dates.isEmpty) return '';
  final DateTime first = r.dates.first;
  final DateTime last = r.dates.last;
  if (r.dates.length == 1) return IstFormat.day(first);
  if (first.month == last.month && first.year == last.year) {
    return '${first.day} – ${IstFormat.day(last)}';
  }
  return '${IstFormat.day(first)} – ${IstFormat.day(last)}';
}

/// The card title: "Short duty · Fri, 20 Nov", "Sick leave · 24 – 26 Nov".
/// The date never breaks across lines.
String myRequestTitle(AppRequest r) {
  final String days = switch (r.kind) {
    RequestKind.shortDuty => IstFormat.weekdayDay(r.day!),
    _ => requestDays(r),
  }.replaceAll(' ', '\u00A0');
  final String kind = switch (r.kind) {
    RequestKind.shortDuty => 'Short duty',
    RequestKind.attendance => 'Attendance',
    RequestKind.leave => r.leaveType?.label ?? 'Leave',
  };
  return '$kind · $days';
}

/// The pill colour and word for a request's status.
(DsStatus, String) requestStatusLook(RequestStatus s) => switch (s) {
  RequestStatus.pending => (DsStatus.waiting, 'Waiting'),
  RequestStatus.approved => (DsStatus.present, 'Approved'),
  RequestStatus.rejected => (DsStatus.absent, 'Rejected'),
  RequestStatus.cancelled => (DsStatus.off, 'Cancelled'),
};

/// The icon and its colours for a request's kind.
(IconData, DsStatus) requestKindLook(AppRequest r) => switch (r.kind) {
  RequestKind.shortDuty => (DsIcons.clock, DsStatus.waiting),
  RequestKind.attendance => (DsIcons.attendance, DsStatus.onDuty),
  RequestKind.leave =>
    r.leaveType == LeaveType.sick
        ? (DsIcons.sickLeave, DsStatus.sick)
        : (DsIcons.casualLeave, DsStatus.leave),
};

/// One sent request: type icon, title, what it is, status pill; waiting
/// ones show the steps, decided ones the admin's note.
class MyRequestCard extends ConsumerWidget {
  const MyRequestCard({required this.request, required this.onTap, super.key});

  final AppRequest request;
  final VoidCallback onTap;

  String _subtitle(WidgetRef ref) {
    final AppRequest r = request;
    final String sent = 'sent ${IstFormat.shortDate(r.createdAt)}';
    final String decided =
        r.status == RequestStatus.approved &&
            r.decision != null &&
            r.kind != RequestKind.leave
        ? ' · ${r.decision!.label}'
        : '';
    switch (r.kind) {
      case RequestKind.shortDuty:
        final DutyDay? d = ref
            .watch(requestDayProvider((r.userId, r.day!)))
            .value;
        final int? minutes = d?.workedMinutes;
        return minutes == null
            ? 'Sent by the app$decided'
            : '${IstFormat.hoursMinutes(Duration(minutes: minutes))} worked'
                  ' · sent by the app$decided';
      case RequestKind.attendance:
        return 'Sent ${IstFormat.shortDate(r.createdAt)}$decided';
      case RequestKind.leave:
        final int n = r.dates.length;
        return '$n ${n == 1 ? 'day' : 'days'} · $sent';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppRequest r = request;
    final (DsStatus pill, String pillLabel) = requestStatusLook(r.status);
    final (IconData icon, DsStatus tone) = requestKindLook(r);
    final String? note = r.decisionNote?.trim();
    final bool showNote =
        note != null &&
        note.isNotEmpty &&
        (r.status == RequestStatus.approved ||
            r.status == RequestStatus.rejected);
    final bool approved = r.status == RequestStatus.approved;
    return Material(
      color: DsColors.white,
      borderRadius: DsRadius.large,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tone.tint,
                      borderRadius: DsRadius.medium,
                    ),
                    child: Icon(icon, size: 20, color: tone.text),
                  ),
                  const SizedBox(width: DsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          myRequestTitle(r),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DsText.body.copyWith(
                            fontWeight: FontWeight.w700,
                            fontVariations: const <FontVariation>[
                              FontVariation('wght', 700),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(ref),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DsText.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DsSpace.sm),
                  DsStatusPill(status: pill, label: pillLabel),
                ],
              ),
              if (r.isPending) ...<Widget>[
                const SizedBox(height: DsSpace.md),
                const RequestSteps(),
              ],
              if (showNote) ...<Widget>[
                const SizedBox(height: DsSpace.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DsSpace.md,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: approved
                        ? DsColors.successTint
                        : const Color(0xFFFEF2F2),
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
                      color: approved
                          ? const Color(0xFF14532D)
                          : const Color(0xFF991B1B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Sent → Admin reviewing → Decision, for a waiting request.
class RequestSteps extends StatelessWidget {
  const RequestSteps({super.key});

  @override
  Widget build(BuildContext context) {
    Widget step(String label, Color bar, Color text, {bool bold = true}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: bar,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsText.micro.copyWith(
                  color: text,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  fontVariations: <FontVariation>[
                    FontVariation('wght', bold ? 700 : 600),
                  ],
                ),
              ),
            ],
          ),
        );
    return Semantics(
      label: 'Sent, admin reviewing, decision pending',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          step('Sent', DsStatus.present.dot, DsStatus.present.text),
          const SizedBox(width: DsSpace.xs),
          step('Admin reviewing', DsStatus.waiting.dot, DsStatus.waiting.text),
          const SizedBox(width: DsSpace.xs),
          step('Decision', DsColors.line, DsColors.text3, bold: false),
        ],
      ),
    );
  }
}
