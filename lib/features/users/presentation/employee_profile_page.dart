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
import '../../../shared/ds/ds_frame.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/domain/auth_status.dart';
import '../../duty/domain/duty_day.dart';
import '../../routes/application/route_providers.dart';
import '../../routes/domain/day_route.dart';
import '../../routes/domain/history_month.dart';
import '../../routes/domain/live_position.dart';
import '../../routes/presentation/day_route_page.dart' show HoursStrip;
import '../../routes/presentation/recent_days.dart';
import '../../routes/presentation/route_parts.dart' show formatKm;
import '../../visits/application/visits_providers.dart';
import '../application/users_providers.dart';
import '../data/users_repository.dart';
import '../domain/profile.dart';
import '../domain/team.dart';
import '../domain/temp_pin.dart';
import 'duty_on_permission_row.dart';
import 'pin_dialog.dart';
import 'users_page.dart' show TeamAvatar, callPhone;

/// "Employee profile" (design v2): who, how they are today, this month,
/// and their account (phone lock, account on, late duty on, password).
/// Opened from Team.
class EmployeeProfilePage extends ConsumerWidget {
  const EmployeeProfilePage({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Profile?> user = ref.watch(userByIdProvider(userId));
    final Profile? p = user.value;
    if (p == null) {
      return Scaffold(
        backgroundColor: DsColors.surface,
        appBar: AppBar(backgroundColor: DsColors.surface),
        body: user.hasError
            ? DsErrorState(
                title: "Couldn't load this person",
                message: 'Check the internet and try again.',
                onRetry: () => ref.invalidate(userByIdProvider(userId)),
              )
            : user.isLoading
            ? const Center(child: CircularProgressIndicator())
            : DsEmptyState(
                title: 'Not found',
                message: AuthFailure.userNotFound.message,
                icon: DsIcons.profile,
              ),
      );
    }
    final DateTime now = ref.watch(serverClockProvider).now();
    final AuthStatus auth = ref.watch(authStatusProvider);
    final List<DutyDay> days =
        ref.watch(todayDaysProvider).value ?? const <DutyDay>[];
    final List<LivePosition> positions =
        ref.watch(livePositionsProvider).value ?? const <LivePosition>[];
    final TeamMember m = teamMembers(
      people: <Profile>[p],
      days: days,
      positions: positions,
      now: now,
      selfId: auth is SignedIn ? auth.userId : null,
    ).single;
    final bool employee = p.role == AppRole.employee;
    return Scaffold(
      backgroundColor: DsColors.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(todayDaysProvider)
            ..invalidate(historyProvider(userId))
            ..invalidate(dutyOnAllowedProvider(userId))
            ..invalidate(userByIdProvider(userId));
          await ref.read(userByIdProvider(userId).future);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            _Top(member: m),
            Padding(
              padding: EdgeInsets.fromLTRB(
                DsSpace.gutter,
                14,
                DsSpace.gutter,
                28 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (employee && p.isActive) ...<Widget>[
                    _Today(member: m, now: now),
                    const SizedBox(height: DsSpace.md),
                  ],
                  if (employee) ...<Widget>[
                    _Month(userId: p.id, now: now),
                    const SizedBox(height: DsSpace.md),
                  ],
                  _Account(member: m),
                  const SizedBox(height: DsSpace.md),
                  DsButton(
                    label: 'Edit details',
                    icon: DsIcons.edit,
                    kind: DsButtonKind.secondary,
                    onPressed: () => context.push(Routes.adminUserEdit(p.id)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tint of a group's top block.
Color _topTint(TeamGroup g) => g == TeamGroup.notStarted || g == TeamGroup.off
    ? const Color(0xFFEEF2F6)
    : g.tone.tint;

class _Top extends ConsumerWidget {
  const _Top({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TeamMember m = member;
    final Profile p = m.profile;
    final DsStatus t = m.group.tone;
    final Color strong =
        m.group == TeamGroup.notStarted || m.group == TeamGroup.off
        ? const Color(0xFF334155)
        : t.text;
    final String? phone = p.phone?.trim();
    final DutyDay? day = m.day;
    final bool hadDuty = day?.dutyOnAt != null;
    return Container(
      decoration: BoxDecoration(
        color: _topTint(m.group),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        DsSpace.gutter,
        MediaQuery.paddingOf(context).top + DsSpace.md,
        DsSpace.gutter,
        20,
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
                  m.isAdmin ? 'Admin' : 'Employee',
                  textAlign: TextAlign.center,
                  style: DsText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: strong,
                  ),
                ),
              ),
              DsIconButton(
                icon: DsIcons.edit,
                label: 'Edit details',
                onPressed: () => context.push(Routes.adminUserEdit(p.id)),
              ),
            ],
          ),
          const SizedBox(height: DsSpace.md),
          TeamAvatar(
            name: p.fullName,
            group: m.group,
            live: m.live,
            size: 92,
            solid: true,
          ),
          const SizedBox(height: DsSpace.sm),
          Semantics(
            header: true,
            child: Text(
              p.fullName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DsText.title,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${p.userCode} · ${p.designation ?? (m.isAdmin ? 'Admin' : 'Employee')}',
            style: DsText.label.copyWith(
              color: strong,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (!m.isAdmin) ...<Widget>[
            const SizedBox(height: DsSpace.sm),
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
                      color: t.dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      m.line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.caption.copyWith(
                        color: strong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (p.isActive) ...<Widget>[
              const SizedBox(height: DsSpace.lg),
              Row(
                children: <Widget>[
                  _Quick(
                    icon: DsIcons.phone,
                    label: 'Call',
                    filled: true,
                    colour: strong,
                    onTap: phone == null || phone.isEmpty
                        ? null
                        : () => callPhone(context, ref, phone),
                  ),
                  _Quick(
                    icon: DsIcons.pin,
                    label: 'Live map',
                    colour: strong,
                    onTap: !hadDuty
                        ? null
                        : () => context.go(
                            '${Routes.adminLiveMap}?day=${day!.id}',
                          ),
                  ),
                  _Quick(
                    icon: DsIcons.route,
                    label: 'Route',
                    colour: strong,
                    onTap: !hadDuty
                        ? null
                        : () => context.push(Routes.adminDay(day!.id)),
                  ),
                  _Quick(
                    icon: DsIcons.history,
                    label: 'History',
                    colour: strong,
                    onTap: () => context.push(Routes.adminUserDays(p.id)),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({
    required this.icon,
    required this.label,
    required this.colour,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color colour;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bool on = onTap != null;
    return Expanded(
      child: Semantics(
        button: true,
        enabled: on,
        label: label,
        excludeSemantics: true,
        child: Opacity(
          opacity: on ? 1 : 0.45,
          child: InkWell(
            onTap: onTap,
            borderRadius: DsRadius.medium,
            child: Column(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: filled ? colour : DsColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: filled ? DsColors.white : colour,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: DsText.caption.copyWith(
                    color: colour,
                    fontWeight: FontWeight.w700,
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

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(DsSpace.lg),
    decoration: const BoxDecoration(
      color: DsColors.white,
      borderRadius: DsRadius.large,
    ),
    child: child,
  );
}

Widget _cardTitle(String title, String? right) => Row(
  crossAxisAlignment: CrossAxisAlignment.baseline,
  textBaseline: TextBaseline.alphabetic,
  children: <Widget>[
    Expanded(
      child: Semantics(header: true, child: Text(title, style: DsText.section)),
    ),
    if (right != null) Text(right, style: DsText.caption),
  ],
);

/// Today: on duty time, distance, visits, battery and the hours strip.
class _Today extends ConsumerWidget {
  const _Today({required this.member, required this.now});

  final TeamMember member;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DutyDay? d = member.day;
    final String date = IstFormat.weekdayDay(Ist.dateOf(now));
    if (d == null || d.dutyOnAt == null) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _cardTitle('Today', date),
            const SizedBox(height: DsSpace.sm),
            Text(switch (d?.status) {
              DayStatus.leave => '${d!.leaveType?.label ?? 'Leave'} today.',
              DayStatus.absent => 'Marked absent today.',
              _ => 'No duty on yet today.',
            }, style: DsText.body.copyWith(color: DsColors.text2)),
          ],
        ),
      );
    }
    final DayRoute? route = ref.watch(dayViewProvider(d.id)).value?.route;
    final int visits = ref.watch(dayVisitsProvider(d.id)).value?.length ?? 0;
    final Duration? worked = dutyLength(d, now);
    final int? battery = member.position?.battery;
    Widget figure(String value, String label, Color bg, Color fg) => Expanded(
      child: Semantics(
        container: true,
        label: '$label $value',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: DsRadius.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: DsText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              Text(label, maxLines: 1, style: DsText.micro.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _cardTitle('Today', date),
          const SizedBox(height: DsSpace.md),
          Row(
            children: <Widget>[
              figure(
                worked == null ? '–' : IstFormat.hoursMinutes(worked),
                d.status == DayStatus.onDuty ? 'On duty' : 'Worked',
                DsColors.successTint,
                const Color(0xFF14532D),
              ),
              const SizedBox(width: 6),
              figure(
                formatKm(route?.distanceM ?? d.distanceM ?? 0),
                'Distance',
                DsColors.primaryTint,
                DsColors.deep,
              ),
              const SizedBox(width: 6),
              figure(
                '$visits',
                'Visits',
                DsStatus.leave.tint,
                const Color(0xFF4C1D95),
              ),
              const SizedBox(width: 6),
              figure(
                battery == null || d.status != DayStatus.onDuty
                    ? '–'
                    : '$battery%',
                'Battery',
                battery != null && battery <= 20 && d.status == DayStatus.onDuty
                    ? DsColors.dangerTint
                    : const Color(0xFFEEF2F6),
                battery != null && battery <= 20 && d.status == DayStatus.onDuty
                    ? DsColors.dangerText
                    : const Color(0xFF334155),
              ),
            ],
          ),
          const SizedBox(height: DsSpace.md),
          HoursStrip(day: d, notes: route?.notes ?? const <RouteNote>[]),
        ],
      ),
    );
  }
}

/// This month: days counted, the counts and the last 30 days.
class _Month extends ConsumerWidget {
  const _Month({required this.userId, required this.now});

  final String userId;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime today = Ist.dateOf(now);
    final List<DutyDay> all =
        ref.watch(historyProvider(userId)).value ?? const <DutyDay>[];
    final HistoryMonth month = HistoryMonth.of(
      today,
      all,
      today: today,
      earliest: today.subtract(const Duration(days: historyDays)),
    );
    final Map<DateTime, DayStatus> byDay = <DateTime, DayStatus>{
      for (final DutyDay d in all) d.day: d.status,
    };
    final List<(DayStatus, String, Color)> parts = <(DayStatus, String, Color)>[
      (DayStatus.present, 'Present', RecentDayColours.present),
      (DayStatus.halfDay, 'Half day', RecentDayColours.half),
      (DayStatus.leave, 'Leave', RecentDayColours.leave),
      (DayStatus.absent, 'Absent', RecentDayColours.absent),
    ];
    final int total = parts.fold(
      0,
      (int s, (DayStatus, String, Color) p) => s + month.count(p.$1),
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    DateFormat('MMMM').format(today),
                    style: DsText.section,
                  ),
                ),
              ),
              SmallOutlineButton(
                label: 'Full history',
                onPressed: () => context.push(Routes.adminUserDays(userId)),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                formatDaysCounted(month.daysCounted),
                style: DsText.number.copyWith(fontSize: 32),
              ),
              const SizedBox(width: DsSpace.xs),
              const Flexible(
                child: Text('days counted', style: DsText.caption),
              ),
            ],
          ),
          const SizedBox(height: DsSpace.md),
          ClipRRect(
            borderRadius: DsRadius.pill,
            child: SizedBox(
              height: 10,
              child: total == 0
                  ? Container(color: RecentDayColours.none)
                  : Row(
                      children: <Widget>[
                        for (final (DayStatus s, String _, Color c) in parts)
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
          const SizedBox(height: DsSpace.md),
          Row(
            children: <Widget>[
              for (final (DayStatus s, String label, Color c) in parts)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${month.count(s)}',
                        style: DsText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DsText.caption,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: DsSpace.md),
          Text(
            'Last 30 days',
            style: DsText.micro.copyWith(
              color: DsColors.text2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          RecentDaysGrid(
            days: <DateTime>[
              for (int i = 29; i >= 0; i--) today.subtract(Duration(days: i)),
            ],
            byDay: byDay,
            ring: today,
            ringColour: DsColors.successDot,
            height: 14,
          ),
        ],
      ),
    );
  }
}

/// Phone, email, phone lock, account on, late duty on, reset password.
class _Account extends ConsumerStatefulWidget {
  const _Account({required this.member});

  final TeamMember member;

  @override
  ConsumerState<_Account> createState() => _AccountState();
}

class _AccountState extends ConsumerState<_Account> {
  bool _busy = false;

  Profile get _p => widget.member.profile;

  bool get _self {
    final AuthStatus auth = ref.watch(authStatusProvider);
    return auth is SignedIn && auth.userId == _p.id;
  }

  void _reload() => ref
    ..invalidate(usersListProvider)
    ..invalidate(userByIdProvider(_p.id));

  /// Runs [action] and says what went wrong, if anything.
  Future<bool> _run(Future<void> Function(UsersRepository repo) action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await action(ref.read(usersRepositoryProvider));
      return true;
    } on AuthFailure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    } on FieldErrors catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.fields.values.firstOrNull ?? AuthFailure.unknown.message,
          ),
        ),
      );
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.unknown.message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  Future<void> _setActive(bool on) async {
    final Profile p = _p;
    if (!on) {
      final bool sure = await showDsConfirm(
        context: context,
        title: 'Turn off ${p.fullName}?',
        message:
            'They are signed out and cannot sign in until you turn the '
            'account back on. Their records stay.',
        confirm: 'Turn off',
        keep: 'Keep it on',
      );
      if (!sure || !mounted) return;
    }
    final bool ok = await _run(
      (UsersRepository repo) => repo.update(
        p.id,
        ProfileDraft(
          userCode: p.userCode,
          fullName: p.fullName,
          phone: p.phone ?? '',
          contactEmail: p.contactEmail ?? '',
          designation: p.designation ?? '',
          role: p.role,
          isActive: on,
        ),
      ),
    );
    if (ok) _reload();
  }

  Future<void> _releasePhone() async {
    final Profile p = _p;
    final bool sure = await showDsConfirm(
      context: context,
      title: "Release ${p.fullName}'s phone?",
      message:
          'Use this when their phone is lost, broken or the app was '
          'reinstalled. That phone is logged out, and they can log in on '
          'another phone with the same password. A running duty carries on '
          'there.',
      confirm: 'Release phone',
      kind: DsButtonKind.primary,
      keep: 'Cancel',
    );
    if (!sure || !mounted) return;
    bool held = false;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await _run((UsersRepository repo) async {
      held = await repo.releasePhone(p.id);
    });
    if (!ok) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          held
              ? 'Phone released. ${p.fullName} can log in on another phone.'
              : 'No phone was logged in.',
        ),
      ),
    );
    _reload();
  }

  Future<void> _resetPassword() async {
    final Profile p = _p;
    final bool sure = await showDsConfirm(
      context: context,
      title: 'Reset password for ${p.fullName}?',
      message:
          'Their phone is signed out, and they sign in again with a new '
          'temporary PIN. Use this when they forgot their password or '
          'changed phones.',
      confirm: 'Reset password',
      kind: DsButtonKind.primary,
      keep: 'Cancel',
    );
    if (!sure || !mounted) return;
    final String pin = generateTempPin();
    final bool ok = await _run(
      (UsersRepository repo) => repo.resetPin(p.id, tempPin: pin),
    );
    if (!ok || !mounted) return;
    await showPinDialog(
      context,
      title: 'Password reset',
      userCode: p.userCode,
      pin: pin,
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final TeamMember m = widget.member;
    final Profile p = _p;
    final bool self = _self;
    final bool employee = p.role == AppRole.employee;
    final String? phone = p.phone?.trim();
    final String? email = p.contactEmail?.trim();
    final List<Widget> rows = <Widget>[
      _Row(
        icon: DsIcons.phone,
        label: 'Phone',
        value: phone == null || phone.isEmpty ? 'Not added' : phone,
        warn: phone == null || phone.isEmpty,
        action: phone == null || phone.isEmpty ? 'Add' : null,
        onAction: () => context.push(Routes.adminUserEdit(p.id)),
      ),
      _Row(
        icon: DsIcons.mail,
        label: 'Email for password reset',
        value: email == null || email.isEmpty ? 'Not added' : email,
        warn: email == null || email.isEmpty,
        action: email == null || email.isEmpty ? 'Add' : null,
        onAction: () => context.push(Routes.adminUserEdit(p.id)),
      ),
      if (employee)
        _Row(
          icon: DsIcons.lock,
          tone: p.hasPhoneSignedIn ? DsStatus.present : null,
          label: 'Phone lock',
          value: p.hasPhoneSignedIn
              ? 'Signed in on one phone'
              : 'Not signed in on any phone',
          help: p.hasPhoneSignedIn
              ? 'Lost or new phone? Release it. The password stays the same.'
              : null,
          trailing: p.hasPhoneSignedIn && !self
              ? SmallOutlineButton(
                  label: 'Release phone',
                  onPressed: _busy ? null : _releasePhone,
                )
              : null,
        ),
      if (!self)
        _Row(
          icon: DsIcons.check,
          tone: p.isActive ? DsStatus.onDuty : DsStatus.absent,
          title: 'Account on',
          help: p.isActive
              ? 'When off, ${firstNameOfProfile(p)} cannot sign in'
              : "Can't sign in until turned back on",
          trailing: Semantics(
            label: 'Account on',
            child: Switch(
              value: p.isActive,
              activeTrackColor: DsColors.primary,
              onChanged: _busy ? null : _setActive,
            ),
          ),
        ),
      if (employee && p.isActive)
        DutyOnPermissionRow(user: p, dayRecorded: m.day != null),
      if (!self)
        _Row(
          icon: DsIcons.lock,
          tone: DsStatus.waiting,
          title: 'Reset password',
          help: 'New PIN, signs out every phone',
          onTap: _busy ? null : _resetPassword,
        ),
    ];
    return _Card(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, 6, DsSpace.lg, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Semantics(
              header: true,
              child: const Text('Account', style: DsText.section),
            ),
          ),
          for (final (int i, Widget r) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: i == rows.length - 1
                  ? null
                  : const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFEEF2F6)),
                      ),
                    ),
              child: r,
            ),
        ],
      ),
    );
  }
}

/// "Rahul" for "Rahul Das".
String firstNameOfProfile(Profile p) =>
    p.fullName.trim().split(RegExp(r'\s+')).first;

/// One account row: an icon tile, a small label over a bold value (or a
/// bold title over a help line), and an action on the right.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    this.tone,
    this.label,
    this.value,
    this.title,
    this.help,
    this.warn = false,
    this.action,
    this.onAction,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final DsStatus? tone;
  final String? label;
  final String? value;
  final String? title;
  final String? help;
  final bool warn;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final DsStatus? t = tone;
    final Widget row = Row(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: t?.tint ?? const Color(0xFFEEF2F6),
            borderRadius: DsRadius.medium,
          ),
          child: Icon(
            icon,
            size: 18,
            color: t?.text ?? const Color(0xFF334155),
          ),
        ),
        const SizedBox(width: DsSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (label case final String l) Text(l, style: DsText.caption),
              if (value case final String v)
                Text(
                  v,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DsText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: warn ? DsColors.warningText : DsColors.ink,
                  ),
                ),
              if (title case final String ti)
                Text(
                  ti,
                  style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              if (help case final String h) Text(h, style: DsText.caption),
            ],
          ),
        ),
        if (action case final String a) ...<Widget>[
          const SizedBox(width: DsSpace.sm),
          DsTextLink(label: a, onPressed: onAction),
        ],
        if (trailing case final Widget w) ...<Widget>[
          const SizedBox(width: DsSpace.sm),
          w,
        ],
        if (onTap != null)
          const Icon(DsIcons.forward, size: 16, color: DsColors.text3),
      ],
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '${title ?? label}${help == null ? '' : ', $help'}',
      excludeSemantics: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
