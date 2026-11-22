import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/links/open_link.dart';
import '../../../core/time/clock_providers.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_field.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../../duty/domain/duty_day.dart';
import '../../routes/application/route_providers.dart';
import '../../routes/domain/live_position.dart';
import '../application/users_providers.dart';
import '../domain/profile.dart';
import '../domain/team.dart';

/// The status tiles at the top of Team; each filters the list.
enum TeamTile {
  onDuty('On duty', DsStatus.present, DsIcons.check),
  attention('No update', DsStatus.waiting, DsIcons.pin),
  leave('On leave', DsStatus.leave, DsIcons.history),
  notStarted('Not started', DsStatus.off, DsIcons.clock);

  const TeamTile(this.label, this.tone, this.icon);

  final String label;
  final DsStatus tone;
  final IconData icon;

  /// "On duty" counts everyone on duty now, fresh or not.
  bool matches(TeamMember m) => switch (this) {
    onDuty => m.group == TeamGroup.onDuty || m.group == TeamGroup.attention,
    attention => m.group == TeamGroup.attention,
    leave => m.group == TeamGroup.leave,
    notStarted => m.group == TeamGroup.notStarted,
  };
}

enum _Role { all, staff, admin }

/// "Team" (design v2): everyone with today's state, grouped, with status
/// tiles, search and a role switch. A tap opens the person's profile.
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  String _query = '';
  TeamTile? _tile;
  _Role _role = _Role.all;

  bool _keep(TeamMember m) {
    final String q = _query.trim().toLowerCase();
    if (q.isNotEmpty && !m.matches(q)) return false;
    if (_tile case final TeamTile t when !t.matches(m)) return false;
    return switch (_role) {
      _Role.all => true,
      _Role.staff => !m.isAdmin,
      _Role.admin => m.isAdmin,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Profile>> users = ref.watch(usersListProvider);
    final List<DutyDay> days =
        ref.watch(todayDaysProvider).value ?? const <DutyDay>[];
    final List<LivePosition> positions =
        ref.watch(livePositionsProvider).value ?? const <LivePosition>[];
    final AuthStatus auth = ref.watch(authStatusProvider);
    final DateTime now = ref.watch(serverClockProvider).now();
    final List<TeamMember> all = teamMembers(
      people: users.value ?? const <Profile>[],
      days: days,
      positions: positions,
      now: now,
      selfId: auth is SignedIn ? auth.userId : null,
    );
    final List<TeamMember> shown = all.where(_keep).toList();
    final int admins = all.where((TeamMember m) => m.isAdmin).length;
    final int staff = all.length - admins;

    return Scaffold(
      backgroundColor: DsColors.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(todayDaysProvider)
              ..invalidate(usersListProvider);
            await ref.read(usersListProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DsSpace.gutter,
              DsSpace.md,
              DsSpace.gutter,
              DsSpace.xl,
            ),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: DsSpace.xs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Semantics(
                            header: true,
                            child: const Text('Team', style: DsText.title),
                          ),
                          Text(
                            !users.hasValue
                                ? ' '
                                : '${all.length} '
                                      '${all.length == 1 ? 'person' : 'people'}'
                                      ' · $staff staff, $admins '
                                      '${admins == 1 ? 'admin' : 'admins'}',
                            style: DsText.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Semantics(
                    container: true,
                    button: true,
                    label: 'Add user',
                    excludeSemantics: true,
                    child: Material(
                      color: DsColors.primary,
                      shape: const CircleBorder(),
                      elevation: 4,
                      shadowColor: const Color(0x4D016893),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.push(Routes.adminUserNew),
                        child: const SizedBox.square(
                          dimension: 46,
                          child: Icon(
                            DsIcons.add,
                            size: 20,
                            color: DsColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  for (final TeamTile t in TeamTile.values) ...<Widget>[
                    if (t != TeamTile.onDuty) const SizedBox(width: DsSpace.sm),
                    Expanded(
                      child: _Tile(
                        tile: t,
                        count: all.where(t.matches).length,
                        selected: _tile == t,
                        onTap: () =>
                            setState(() => _tile = _tile == t ? null : t),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DsSearchField(
                      hint: 'Name or user ID',
                      floating: true,
                      onChanged: (String v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: DsSpace.sm),
                  _RoleSwitch(
                    role: _role,
                    onPick: (_Role r) => setState(() => _role = r),
                  ),
                ],
              ),
              const SizedBox(height: DsSpace.md),
              if (users.hasError && !users.hasValue)
                DsErrorState(
                  title: "Couldn't load the team",
                  message: 'Check the internet and try again.',
                  onRetry: () => ref.invalidate(usersListProvider),
                )
              else if (!users.hasValue)
                const Padding(
                  padding: EdgeInsets.only(top: DsSpace.xxl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (shown.isEmpty)
                DsEmptyState(
                  title: all.isEmpty ? 'No users yet' : 'No match',
                  message: all.isEmpty
                      ? 'Add your first user with the + button.'
                      : 'Nobody matches this search or filter.',
                  icon: DsIcons.team,
                )
              else
                for (final TeamGroup g in TeamGroup.values)
                  if (shown.where((TeamMember m) => m.group == g).toList()
                      case final List<TeamMember> people
                      when people.isNotEmpty) ...<Widget>[
                    _GroupTitle(
                      group: g,
                      count: all.where((TeamMember m) => m.group == g).length,
                    ),
                    for (final TeamMember m in people) ...<Widget>[
                      const SizedBox(height: DsSpace.sm),
                      _MemberCard(member: m),
                    ],
                    const SizedBox(height: DsSpace.lg),
                  ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.tile,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final TeamTile tile;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DsStatus t = tile.tone;
    final Color strong = tile == TeamTile.notStarted
        ? const Color(0xFF475569)
        : t.text;
    return Semantics(
      button: true,
      selected: selected,
      label: '${tile.label}, $count',
      excludeSemantics: true,
      child: Material(
        color: selected ? strong : t.tint,
        borderRadius: DsRadius.large,
        clipBehavior: Clip.antiAlias,
        elevation: selected ? 4 : 0,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 96,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected ? const Color(0x38FFFFFF) : DsColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    tile.icon,
                    size: 15,
                    color: selected ? DsColors.white : strong,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$count',
                      style: DsText.title.copyWith(
                        height: 1,
                        color: selected ? DsColors.white : strong,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tile.label,
                        maxLines: 1,
                        style: DsText.micro.copyWith(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? DsColors.white
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSwitch extends StatelessWidget {
  const _RoleSwitch({required this.role, required this.onPick});

  final _Role role;
  final ValueChanged<_Role> onPick;

  @override
  Widget build(BuildContext context) {
    Widget seg(_Role r, String label) => Semantics(
      button: true,
      selected: r == role,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onPick(r),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: r == role ? DsColors.white : Colors.transparent,
            borderRadius: DsRadius.pill,
            boxShadow: r == role ? DsShadow.card : null,
          ),
          child: Text(
            label,
            style: DsText.label.copyWith(
              fontWeight: FontWeight.w700,
              color: r == role ? DsColors.ink : DsColors.text2,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Color(0xFFEEF2F6),
        borderRadius: DsRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          seg(_Role.all, 'All'),
          seg(_Role.staff, 'Staff'),
          seg(_Role.admin, 'Admin'),
        ],
      ),
    );
  }
}

/// "● On duty (16) ———".
class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.group, required this.count});

  final TeamGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: group.tone.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: DsSpace.sm),
          Semantics(
            header: true,
            child: Text(
              group.title,
              style: DsText.label.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: DsSpace.sm),
          Container(
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: DsColors.white,
              borderRadius: DsRadius.pill,
            ),
            child: Text(
              '$count',
              style: DsText.micro.copyWith(
                fontWeight: FontWeight.w700,
                color: DsColors.text2,
              ),
            ),
          ),
          const SizedBox(width: DsSpace.sm),
          const Expanded(child: Divider(height: 1, color: Color(0xFFDCE3EA))),
        ],
      ),
    );
  }
}

/// Initials in the group's colours inside a status ring, with a green dot
/// while live.
class TeamAvatar extends StatelessWidget {
  const TeamAvatar({
    required this.name,
    required this.group,
    required this.live,
    this.size = 50,
    this.solid = false,
    super.key,
  });

  final String name;
  final TeamGroup group;
  final bool live;
  final double size;

  /// A filled circle with white initials (the profile's big avatar).
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final DsStatus t = group.tone;
    final Color ring = group == TeamGroup.off || group == TeamGroup.notStarted
        ? const Color(0xFFCBD5E1)
        : t.dot;
    final double dot = size * 0.24;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: <Widget>[
          Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(size * 0.06),
            decoration: BoxDecoration(
              color: DsColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: size * 0.05),
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: solid ? t.text : t.tint,
                shape: BoxShape.circle,
              ),
              child: Text(
                initialsOf(name),
                style: (size > 60 ? DsText.title : DsText.body).copyWith(
                  fontWeight: FontWeight.w700,
                  color: solid ? DsColors.white : t.text,
                ),
              ),
            ),
          ),
          if (live)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: DsColors.successDot,
                  shape: BoxShape.circle,
                  border: Border.all(color: DsColors.white, width: dot * 0.22),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens the phone's dialler for [phone]; says so when it cannot.
Future<void> callPhone(
  BuildContext context,
  WidgetRef ref,
  String phone,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final bool opened = await ref.read(openLinkProvider)(
    Uri(scheme: 'tel', path: phone),
  );
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Couldn't open the phone app.")),
    );
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TeamMember m = member;
    final Profile p = m.profile;
    final DsStatus t = m.group.tone;
    final String? phone = p.phone?.trim();
    final bool canCall =
        !m.isAdmin && p.isActive && phone != null && phone.isNotEmpty;
    return Opacity(
      opacity: m.group == TeamGroup.off ? 0.6 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: m.group == TeamGroup.attention
              ? const Color(0xFFFFFBEB)
              : DsColors.white,
          borderRadius: DsRadius.large,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                button: true,
                label: '${p.fullName}, ${p.userCode}, ${m.line}',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: DsRadius.large,
                  onTap: () => context.push(Routes.adminUserProfile(p.id)),
                  child: Row(
                    children: <Widget>[
                      TeamAvatar(
                        name: p.fullName,
                        group: m.group,
                        live: m.live,
                      ),
                      const SizedBox(width: DsSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    p.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DsText.body.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  p.userCode,
                                  style: DsText.micro.copyWith(
                                    color: DsColors.text2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Container(
                              height: 22,
                              padding: const EdgeInsets.symmetric(
                                horizontal: DsSpace.sm,
                              ),
                              alignment: Alignment.centerLeft,
                              decoration: BoxDecoration(
                                color:
                                    m.group == TeamGroup.off ||
                                        m.group == TeamGroup.notStarted
                                    ? const Color(0xFFEEF2F6)
                                    : t.tint,
                                borderRadius: DsRadius.pill,
                              ),
                              child: Text(
                                m.line,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DsText.micro.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color:
                                      m.group == TeamGroup.notStarted ||
                                          m.group == TeamGroup.off
                                      ? const Color(0xFF475569)
                                      : t.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (canCall) ...<Widget>[
              const SizedBox(width: DsSpace.sm),
              Semantics(
                container: true,
                button: true,
                label: 'Call ${p.fullName}',
                excludeSemantics: true,
                child: Material(
                  color: DsColors.successTint,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => callPhone(context, ref, phone),
                    child: const SizedBox.square(
                      dimension: 40,
                      child: Icon(
                        DsIcons.phone,
                        size: 17,
                        color: DsColors.successText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (m.isAdmin) ...<Widget>[
              const SizedBox(width: DsSpace.sm),
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: DsColors.primaryTint,
                  borderRadius: DsRadius.pill,
                ),
                child: Text(
                  'ADMIN',
                  style: DsText.micro.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DsColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
