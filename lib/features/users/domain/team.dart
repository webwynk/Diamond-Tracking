import '../../../core/design/ds_status.dart';
import '../../../core/time/ist_format.dart';
import '../../auth/domain/auth_status.dart';
import '../../duty/domain/duty_day.dart';
import '../../routes/domain/live_position.dart';
import 'profile.dart';

/// Where a person sits on the Team list today (design v2, Team).
enum TeamGroup {
  attention('Needs attention', DsStatus.waiting),
  onDuty('On duty', DsStatus.present),
  finished('Finished', DsStatus.onDuty),
  leave('On leave', DsStatus.leave),
  notStarted('Not started', DsStatus.off),
  admins('Admins', DsStatus.onDuty),
  off('Account off', DsStatus.off);

  const TeamGroup(this.title, this.tone);

  final String title;
  final DsStatus tone;
}

/// One person on the Team list, with today's state.
class TeamMember {
  const TeamMember({
    required this.profile,
    required this.group,
    required this.line,
    this.day,
    this.position,
  });

  final Profile profile;
  final TeamGroup group;

  /// "Live · since 7:12 AM", "No update · 12 min", "No duty on yet".
  final String line;

  /// Today's duty day, if there is one.
  final DutyDay? day;

  /// The latest position sent today, while on duty.
  final LivePosition? position;

  bool get isAdmin => profile.role == AppRole.admin;

  /// On duty with a fresh position: the green dot.
  bool get live => group == TeamGroup.onDuty;

  /// The name or the user ID contains [q] (lower case).
  bool matches(String q) =>
      profile.fullName.toLowerCase().contains(q) ||
      profile.userCode.toLowerCase().contains(q);
}

/// Everyone, placed in a group by today's duty [days] and [positions],
/// sorted by group then name. [selfId] is the signed-in admin ("You").
List<TeamMember> teamMembers({
  required List<Profile> people,
  required List<DutyDay> days,
  required List<LivePosition> positions,
  required DateTime now,
  String? selfId,
}) {
  final Map<String, DutyDay> dayOf = <String, DutyDay>{
    for (final DutyDay d in days)
      if (d.userId case final String id) id: d,
  };
  final Map<int, LivePosition> posOf = <int, LivePosition>{
    for (final LivePosition p in positions)
      if (p.dutyDayId case final int id) id: p,
  };
  TeamMember place(Profile p) {
    if (!p.isActive) {
      return TeamMember(profile: p, group: TeamGroup.off, line: 'Account off');
    }
    if (p.role == AppRole.admin) {
      return TeamMember(
        profile: p,
        group: TeamGroup.admins,
        line: p.id == selfId ? 'You' : 'Admin',
      );
    }
    final DutyDay? d = dayOf[p.id];
    final LivePosition? pos = d == null ? null : posOf[d.id];
    final String since = d?.dutyOnAt == null
        ? ''
        : ' · since ${IstFormat.time(d!.dutyOnAt!)}';
    if (d != null && d.status == DayStatus.onDuty) {
      if (pos == null) {
        return TeamMember(
          profile: p,
          group: TeamGroup.attention,
          line: 'No location yet$since',
          day: d,
        );
      }
      if (pos.mocked) {
        return TeamMember(
          profile: p,
          group: TeamGroup.attention,
          line: 'Fake GPS · at ${IstFormat.time(pos.recordedAt)}',
          day: d,
          position: pos,
        );
      }
      if (pos.isStaleAt(now)) {
        return TeamMember(
          profile: p,
          group: TeamGroup.attention,
          line:
              'No update · ${IstFormat.duration(now.difference(pos.recordedAt))}',
          day: d,
          position: pos,
        );
      }
      return TeamMember(
        profile: p,
        group: TeamGroup.onDuty,
        line: 'Live$since',
        day: d,
        position: pos,
      );
    }
    if (d != null && d.status == DayStatus.leave) {
      return TeamMember(
        profile: p,
        group: TeamGroup.leave,
        line: '${d.leaveType?.label ?? 'Leave'} today',
        day: d,
      );
    }
    if (d != null && d.dutyOnAt != null) {
      return TeamMember(
        profile: p,
        group: TeamGroup.finished,
        line: d.dutyOffAt == null
            ? d.status.label
            : 'Duty off ${IstFormat.time(d.dutyOffAt!)}'
                  '${d.autoEnded ? ' (auto)' : ''}',
        day: d,
      );
    }
    return TeamMember(
      profile: p,
      group: TeamGroup.notStarted,
      line: d?.status == DayStatus.absent ? 'Absent' : 'No duty on yet',
      day: d,
    );
  }

  return people.map(place).toList()..sort((TeamMember a, TeamMember b) {
    final int g = a.group.index.compareTo(b.group.index);
    if (g != 0) return g;
    return a.profile.fullName.toLowerCase().compareTo(
      b.profile.fullName.toLowerCase(),
    );
  });
}
