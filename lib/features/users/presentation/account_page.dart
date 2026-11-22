import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/app_version.dart';
import '../../../core/config/env.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../application/users_providers.dart';
import '../domain/profile.dart';
import 'log_out.dart';

/// "My account" (design v2): the admin's own name and ID, change password,
/// this phone, notifications, the app version and log out. Opened from the
/// dashboard. (The employee's is ProfilePage.)
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Profile?> me = ref.watch(myProfileProvider);
    final Profile? p = me.value;
    final String? version = ref.watch(appVersionProvider).value;
    final bool push = Env.pushConfigured;
    return Scaffold(
      backgroundColor: DsColors.surface,
      body: me.hasError && p == null
          ? SafeArea(
              child: DsErrorState(
                title: "Couldn't load your account",
                message: 'Check the internet and try again.',
                onRetry: () => ref.invalidate(myProfileProvider),
              ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                _Top(profile: p),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    DsSpace.gutter,
                    18,
                    DsSpace.gutter,
                    28 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _GroupTitle('Security'),
                      _Group(
                        rows: <Widget>[
                          _Row(
                            icon: DsIcons.lock,
                            tone: DsStatus.onDuty,
                            title: 'Change password',
                            help: 'Needs your current password',
                            onTap: () =>
                                context.push(Routes.adminChangePassword),
                          ),
                          const _Row(
                            icon: DsIcons.phone,
                            tone: DsStatus.present,
                            title: 'This phone',
                            help: 'You are signed in here',
                            trailing: _Pill(
                              label: 'Active',
                              status: DsStatus.present,
                              dot: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DsSpace.lg),
                      const _GroupTitle('App'),
                      _Group(
                        rows: <Widget>[
                          _Row(
                            icon: DsIcons.bell,
                            tone: DsStatus.waiting,
                            title: 'Notifications',
                            help: push
                                ? 'Phone alerts for new requests'
                                : 'Phone alerts are off in this build',
                            trailing: _Pill(
                              label: push ? 'On' : 'Off',
                              status: push ? DsStatus.present : DsStatus.off,
                            ),
                            onTap: () =>
                                context.push(Routes.adminNotifications),
                          ),
                          if (version != null)
                            _Row(
                              icon: DsIcons.info,
                              tone: DsStatus.leave,
                              title: 'App version',
                              help: 'Diamond Agritech field app',
                              trailing: _Pill(
                                label: version,
                                status: DsStatus.off,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: DsSpace.lg),
                      DsButton(
                        label: 'Log out',
                        kind: DsButtonKind.dangerSoft,
                        icon: DsIcons.logOut,
                        onPressed: () => logOut(context, ref),
                      ),
                      const SizedBox(height: DsSpace.md),
                      const Text(
                        'Log out here before you sign in on another phone.',
                        textAlign: TextAlign.center,
                        style: DsText.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// The blue top: back, "My account", initials, name, ID and "Admin".
class _Top extends StatelessWidget {
  const _Top({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final Profile? p = profile;
    return Container(
      decoration: const BoxDecoration(
        color: DsColors.primaryTint,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        DsSpace.gutter,
        MediaQuery.paddingOf(context).top + DsSpace.md,
        DsSpace.gutter,
        24,
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
                  'My account',
                  textAlign: TextAlign.center,
                  style: DsText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DsColors.deep,
                  ),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: DsColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: DsColors.primary, width: 3),
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: DsColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                p == null ? '' : initialsOf(p.fullName),
                style: DsText.title.copyWith(color: DsColors.white),
              ),
            ),
          ),
          const SizedBox(height: DsSpace.sm),
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
          const SizedBox(height: DsSpace.sm),
          if (p != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: DsColors.white,
                    borderRadius: DsRadius.pill,
                  ),
                  child: Text(
                    p.userCode,
                    style: DsText.caption.copyWith(
                      color: DsColors.deep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                    color: DsColors.primary,
                    borderRadius: DsRadius.pill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        DsIcons.admin,
                        size: 12,
                        color: DsColors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Admin',
                        style: DsText.caption.copyWith(
                          color: DsColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, DsSpace.sm),
    child: Semantics(
      header: true,
      child: Text(
        title.toUpperCase(),
        style: DsText.micro.copyWith(
          color: DsColors.text2,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: const BoxDecoration(
      color: DsColors.white,
      borderRadius: DsRadius.large,
    ),
    child: Column(
      children: <Widget>[
        for (final (int i, Widget r) in rows.indexed) ...<Widget>[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Divider(height: 1, color: Color(0xFFEEF2F6)),
            ),
          r,
        ],
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tone,
    required this.title,
    required this.help,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final DsStatus tone;
  final String title;
  final String help;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget row = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
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
                  title,
                  style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(help, style: DsText.caption),
              ],
            ),
          ),
          if (trailing case final Widget w) ...<Widget>[
            const SizedBox(width: DsSpace.sm),
            w,
          ] else if (onTap != null)
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(DsIcons.forward, size: 14, color: DsColors.ink),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      container: true,
      button: true,
      label: '$title. $help',
      excludeSemantics: true,
      child: InkWell(borderRadius: DsRadius.large, onTap: onTap, child: row),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.status, this.dot = false});

  final String label;
  final DsStatus status;
  final bool dot;

  @override
  Widget build(BuildContext context) => Container(
    height: 26,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: status == DsStatus.off ? const Color(0xFFEEF2F6) : status.tint,
      borderRadius: DsRadius.pill,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (dot) ...<Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: DsText.caption.copyWith(
            color: status == DsStatus.off
                ? const Color(0xFF334155)
                : status.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
