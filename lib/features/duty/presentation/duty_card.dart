import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/rules/duty_rules.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_chips.dart';
import '../../requests/domain/app_request.dart' show LeaveType;
import '../../visits/application/visits_providers.dart';
import '../../visits/data/visit_outbox.dart';
import '../../visits/domain/visit.dart';
import '../application/phone_battery.dart';
import '../domain/duty_day.dart';
import '../domain/duty_home.dart';

/// The top of the employee Home (design v2): one card that changes with the
/// time of day and today's record, so there is always one clear next step.
class DutyCard extends StatelessWidget {
  const DutyCard({
    required this.home,
    required this.now,
    required this.busy,
    required this.onDutyOn,
    required this.onDutyOff,
    super.key,
  });

  final DutyHome home;
  final DateTime now;
  final bool busy;
  final VoidCallback onDutyOn;
  final void Function(DutyDay day) onDutyOff;

  @override
  Widget build(BuildContext context) {
    final DutyDay? day = home.today;
    return switch (home.phaseAt(now)) {
      DutyPhase.beforeWindow => const _PlainCard(
        icon: DsIcons.clock,
        iconStatus: DsStatus.off,
        title: 'Not on duty',
        subtitle: 'Duty on opens at 5:00 AM',
        button: DsButton(
          label: 'Duty on',
          icon: DsIcons.dutyOn,
          onPressed: null,
        ),
      ),
      DutyPhase.canDutyOn => _StartCard(
        pill: const DsStatusPill(
          status: DsStatus.present,
          label: 'Duty on is open until 8:30 AM',
        ),
        title: 'Ready to start?',
        subtitle: 'Your route is recorded only while you are on duty.',
        busy: busy,
        onDutyOn: onDutyOn,
      ),
      DutyPhase.allowedByAdmin => _StartCard(
        pill: const DsStatusPill(
          status: DsStatus.onDuty,
          label: 'Allowed by your admin',
        ),
        title: 'You can start today',
        subtitle: 'Works once, until 9:00 PM.',
        busy: busy,
        onDutyOn: onDutyOn,
      ),
      DutyPhase.windowClosed => _PlainCard(
        icon: DsIcons.closed,
        iconStatus: DsStatus.absent,
        title: 'Duty on is closed',
        subtitle: 'It is open 5:00 – 8:30 AM only',
        body:
            'Worked today but missed duty on? Ask your admin to count the '
            'day.',
        button: DsButton(
          label: 'Request attendance',
          kind: DsButtonKind.outline,
          onPressed: () => context.push(Routes.userRequestAttendance),
        ),
      ),
      DutyPhase.onDuty => _OnDutyCard(
        day: day!,
        home: home,
        now: now,
        busy: busy,
        onDutyOff: () => onDutyOff(day),
      ),
      DutyPhase.offSaved => _PlainCard(
        icon: DsIcons.upload,
        iconStatus: DsStatus.waiting,
        tint: DsStatus.waiting,
        title: 'Duty off saved',
        subtitle:
            'At ${IstFormat.time(home.session!.offAt!)} · '
            '${IstFormat.duration(home.session!.offAt!.difference(day!.dutyOnAt!))}',
        body:
            'No internet right now. Your phone sends it by itself when the '
            'internet is back. Keep the app installed.',
      ),
      DutyPhase.ended =>
        day!.status == DayStatus.pending
            ? _ReviewWaitCard(day: day, home: home, now: now)
            : _DayDoneCard(day: day, home: home, now: now),
      DutyPhase.onLeave => _LeaveCard(type: day?.leaveType),
    };
  }
}

/// The white card used for most states: an icon in a soft square, a title
/// and a line, then an optional paragraph and button.
class _PlainCard extends StatelessWidget {
  const _PlainCard({
    required this.icon,
    required this.iconStatus,
    required this.title,
    required this.subtitle,
    this.body,
    this.button,
    this.tint,
    this.trailing,
    this.extra,
    this.borderColor,
  });

  final IconData icon;
  final DsStatus iconStatus;
  final String title;
  final String subtitle;
  final String? body;
  final Widget? button;

  /// A tinted card (duty off saved, leave) instead of white.
  final DsStatus? tint;
  final Widget? trailing;
  final Widget? extra;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final Color text = tint?.text ?? DsColors.text2;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tint?.tint ?? DsColors.white,
        borderRadius: DsRadius.large,
        border: tint == null
            ? Border.all(color: borderColor ?? DsColors.line)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tint == null ? iconStatus.tint : DsColors.white,
                  borderRadius: DsRadius.medium,
                ),
                child: Icon(icon, size: 22, color: iconStatus.text),
              ),
              const SizedBox(width: DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: DsText.section.copyWith(
                        color: tint?.text ?? DsColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: DsText.body.copyWith(color: text)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (body case final String b) ...<Widget>[
            const SizedBox(height: DsSpace.md),
            Text(
              b,
              style: DsText.body.copyWith(color: tint?.text ?? DsColors.slate),
            ),
          ],
          if (extra case final Widget e) ...<Widget>[
            const SizedBox(height: DsSpace.lg),
            e,
          ],
          if (button case final Widget b) ...<Widget>[
            const SizedBox(height: DsSpace.lg),
            b,
          ],
        ],
      ),
    );
  }
}

/// Ready to start, or allowed by the admin: a pill, a title and Duty on.
class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.pill,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onDutyOn,
  });

  final Widget pill;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onDutyOn;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: DsColors.white,
      borderRadius: DsRadius.large,
      border: Border.all(color: DsColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        pill,
        const SizedBox(height: DsSpace.lg),
        Text(title, style: DsText.value),
        const SizedBox(height: DsSpace.xs),
        Text(subtitle, style: DsText.body.copyWith(color: DsColors.text2)),
        const SizedBox(height: DsSpace.lg),
        DsButton(
          label: 'Duty on',
          icon: DsIcons.dutyOn,
          busy: busy,
          busyLabel: 'Starting…',
          onPressed: onDutyOn,
        ),
      ],
    ),
  );
}

/// On duty: the deep hero card with worked time, the 10-hour bar, distance,
/// visits and battery, and Duty off.
class _OnDutyCard extends ConsumerWidget {
  const _OnDutyCard({
    required this.day,
    required this.home,
    required this.now,
    required this.busy,
    required this.onDutyOff,
  });

  final DutyDay day;
  final DutyHome home;
  final DateTime now;
  final bool busy;
  final VoidCallback onDutyOff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Duration worked = now.difference(day.dutyOnAt!);
    final Duration left = DutyRules.minimumDuty - worked;
    final double share = (worked.inSeconds / DutyRules.minimumDuty.inSeconds)
        .clamp(0, 1)
        .toDouble();
    final int percent = (share * 100).floor();
    final DateTime autoOff =
        home.session?.autoOffAt ?? DutyRules.autoDutyOffFor(day.dutyOnAt!);
    final int? battery = ref.watch(phoneBatteryProvider).value;
    const TextStyle soft = TextStyle(color: DsColors.skyText);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: DsColors.deep,
        borderRadius: DsRadius.large,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x4701425A),
            offset: Offset(0, 14),
            blurRadius: 32,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const DsStatusPill(status: DsStatus.present, label: 'On duty'),
              const SizedBox(width: DsSpace.sm),
              Expanded(
                child: Text(
                  'Started ${IstFormat.time(day.dutyOnAt!)}',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsText.label.merge(soft),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Worked today', style: DsText.label.merge(soft)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        IstFormat.hoursMinutes(worked),
                        style: DsText.number.copyWith(color: DsColors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      left.isNegative || left == Duration.zero
                          ? '10 h done'
                          : 'Left for 10 h',
                      style: DsText.label.merge(soft),
                    ),
                    if (left > Duration.zero)
                      Text(
                        IstFormat.hoursMinutes(left),
                        style: DsText.section.copyWith(color: DsColors.white),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpace.lg),
          Semantics(
            label: 'Daily goal',
            value: '$percent%',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 10,
                child: Stack(
                  children: <Widget>[
                    const Positioned.fill(
                      child: ColoredBox(color: DsColors.deepRaised),
                    ),
                    FractionallySizedBox(
                      widthFactor: share,
                      child: Container(
                        decoration: BoxDecoration(
                          color: DsColors.liveOnDeep,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '$percent% of the day',
                  style: DsText.micro.merge(soft),
                ),
              ),
              Text(
                'Auto off ${IstFormat.time(autoOff)}',
                style: DsText.micro.merge(soft),
              ),
            ],
          ),
          const SizedBox(height: DsSpace.lg),
          Container(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
            decoration: const BoxDecoration(
              color: DsColors.deepRaised,
              borderRadius: DsRadius.medium,
            ),
            child: IntrinsicHeight(
              child: Row(
                children: <Widget>[
                  _HeroStat(value: kmText(day.distanceM), label: 'Distance'),
                  const VerticalDivider(width: 1, color: Color(0xFF1B6E8F)),
                  _HeroStat(
                    value: '${dayVisitCount(ref, day.id)}',
                    label: 'Visits',
                  ),
                  const VerticalDivider(width: 1, color: Color(0xFF1B6E8F)),
                  _HeroStat(
                    value: battery == null ? '–' : '$battery%',
                    label: 'Battery',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DsSpace.lg),
          DsButton(
            label: 'Duty off',
            kind: DsButtonKind.dangerOnDeep,
            icon: DsIcons.dutyOff,
            busy: busy,
            busyLabel: 'Ending…',
            onPressed: onDutyOff,
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: DsText.section.copyWith(color: DsColors.white),
          ),
        ),
        Text(label, style: DsText.caption.copyWith(color: DsColors.skyText)),
      ],
    ),
  );
}

/// A day the admin has decided.
class _DayDoneCard extends ConsumerWidget {
  const _DayDoneCard({
    required this.day,
    required this.home,
    required this.now,
  });

  final DutyDay day;
  final DutyHome home;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DsStatus status = switch (day.status) {
      DayStatus.present => DsStatus.present,
      DayStatus.halfDay => DsStatus.halfDay,
      DayStatus.absent => DsStatus.absent,
      _ => DsStatus.off,
    };
    final bool present = day.status == DayStatus.present;
    final DateTime? on = day.dutyOnAt;
    final DateTime off = day.dutyOffAt ?? home.session?.offAt ?? now;
    final Duration worked = day.workedMinutes != null
        ? Duration(minutes: day.workedMinutes!)
        : (on == null ? Duration.zero : off.difference(on));
    return _PlainCard(
      icon: present ? DsIcons.dayDone : DsIcons.closed,
      iconStatus: status,
      title: present ? 'Day complete' : 'Day closed',
      subtitle: day.autoEnded
          ? 'Ended by itself at 11:00 PM.'
          : 'Thank you, see you tomorrow',
      trailing: DsStatusPill(status: status, label: day.status.label),
      extra: on == null
          ? null
          : Row(
              children: <Widget>[
                _DoneTile(
                  value: IstFormat.hoursMinutes(worked),
                  label: '${IstFormat.clock(on)} – ${IstFormat.clock(off)}',
                ),
                const SizedBox(width: DsSpace.sm),
                _DoneTile(value: kmText(day.distanceM), label: 'Distance'),
                const SizedBox(width: DsSpace.sm),
                _DoneTile(
                  value: '${dayVisitCount(ref, day.id)}',
                  label: 'Visits',
                ),
              ],
            ),
    );
  }
}

class _DoneTile extends StatelessWidget {
  const _DoneTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: 10),
      decoration: const BoxDecoration(
        color: DsColors.surface,
        borderRadius: DsRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: DsText.button),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsText.caption,
          ),
        ],
      ),
    ),
  );
}

/// Duty off done: waiting for the admin's review (every duty day).
class _ReviewWaitCard extends StatelessWidget {
  const _ReviewWaitCard({
    required this.day,
    required this.home,
    required this.now,
  });

  final DutyDay day;
  final DutyHome home;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final DateTime on = day.dutyOnAt!;
    final DateTime off = day.dutyOffAt ?? home.session?.offAt ?? now;
    final Duration worked = day.workedMinutes != null
        ? Duration(minutes: day.workedMinutes!)
        : off.difference(on);
    return _PlainCard(
      icon: DsIcons.waiting,
      iconStatus: DsStatus.waiting,
      borderColor: const Color(0xFFFCD34D),
      title: 'Waiting for review',
      subtitle: 'Duty ${IstFormat.time(on)} – ${IstFormat.time(off)}',
      body:
          'You worked ${IstFormat.duration(worked)}. The admin will check '
          'your day: present, half day or absent. You will get a '
          'notification.',
    );
  }
}

/// On sick leave today (the only kind of leave).
class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.type});

  final LeaveType? type;

  @override
  Widget build(BuildContext context) {
    return _PlainCard(
      icon: DsIcons.sickLeave,
      iconStatus: DsStatus.sick,
      tint: DsStatus.sick,
      title: 'On leave today',
      subtitle: switch (type) {
        LeaveType.sick => 'Sick leave · approved. Get well soon.',
        null => 'Your leave is approved.',
      },
    );
  }
}

/// "38 km", "0.4 km", or "0 km" before the first upload.
String kmText(int? metres) {
  final int m = metres ?? 0;
  if (m == 0) return '0 km';
  if (m < 10000) return '${(m / 1000).toStringAsFixed(1)} km';
  return '${(m / 1000).round()} km';
}

/// Today's visits from the server plus those still on the phone.
int dayVisitCount(WidgetRef ref, int dayId) {
  final List<Visit> sent =
      ref.watch(dayVisitsProvider(dayId)).value ?? const <Visit>[];
  final List<PendingVisit> waiting =
      ref.watch(pendingVisitsProvider).value ?? const <PendingVisit>[];
  return sent.length + waiting.length;
}
