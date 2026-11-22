import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/app_version.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../requests/application/requests_providers.dart';
import '../../requests/domain/app_request.dart';
import '../application/users_providers.dart';
import '../domain/profile.dart';
import 'log_out.dart';

/// "Profile" (design v2), the employee's tab: who is signed in, account
/// details, change password, My requests, the app version and Log out.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Profile?> me = ref.watch(myProfileProvider);
    final Profile? p = me.value;
    final int waiting =
        ref
            .watch(myRequestsProvider)
            .value
            ?.where((AppRequest r) => r.isPending)
            .length ??
        0;
    final String? version = ref.watch(appVersionProvider).value;
    return Scaffold(
      backgroundColor: DsColors.surface,
      body: me.hasError && p == null
          ? SafeArea(
              child: DsErrorState(
                title: "Couldn't load your profile",
                message: 'Check the internet and try again.',
                onRetry: () => ref.invalidate(myProfileProvider),
              ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                _Header(profile: p),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DsSpace.gutter,
                    DsSpace.lg,
                    DsSpace.gutter,
                    DsSpace.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _Card(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DsSpace.lg,
                          vertical: 6,
                        ),
                        children: <Widget>[
                          _FactRow(
                            icon: DsIcons.phone,
                            label: 'Phone',
                            value: Text(
                              p?.phone ?? 'Not set',
                              style: _bold.copyWith(
                                color: p?.phone == null
                                    ? DsColors.text2
                                    : DsColors.ink,
                              ),
                            ),
                          ),
                          const Divider(height: 1, color: DsColors.disabled),
                          _FactRow(
                            icon: DsIcons.mail,
                            label: 'Reset email',
                            value: p?.contactEmail == null
                                ? const DsTag(label: 'Not set')
                                : const DsTag(
                                    label: 'Saved',
                                    status: DsStatus.present,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DsSpace.md),
                      _Card(
                        padding: const EdgeInsets.all(6),
                        children: <Widget>[
                          _LinkRow(
                            icon: DsIcons.lock,
                            tone: DsStatus.onDuty,
                            label: 'Change password',
                            onTap: () =>
                                context.push(Routes.userChangePassword),
                          ),
                          _LinkRow(
                            icon: DsIcons.requests,
                            tone: DsStatus.leave,
                            label: 'My requests',
                            trailing: waiting == 0
                                ? null
                                : DsTag(
                                    label: '$waiting waiting',
                                    status: DsStatus.waiting,
                                  ),
                            onTap: () => context.push(Routes.userRequests),
                          ),
                          if (version != null)
                            _LinkRow(
                              icon: DsIcons.info,
                              tone: DsStatus.off,
                              label: 'App version',
                              trailing: Text(version, style: DsText.label),
                            ),
                        ],
                      ),
                      const SizedBox(height: DsSpace.md),
                      DsButton(
                        label: 'Log out',
                        kind: DsButtonKind.dangerSoft,
                        icon: DsIcons.logOut,
                        onPressed: () => logOut(context, ref),
                      ),
                      const SizedBox(height: DsSpace.md),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                DsIcons.info,
                                size: 14,
                                color: DsColors.text2,
                              ),
                            ),
                            SizedBox(width: DsSpace.sm),
                            Expanded(
                              child: Text(
                                'Do duty off first. Log out here before '
                                'signing in on another phone.',
                                style: DsText.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  static final TextStyle _bold = DsText.body.copyWith(
    fontWeight: FontWeight.w700,
    fontVariations: const <FontVariation>[FontVariation('wght', 700)],
  );
}

/// The deep header: initials, name, user ID, "Signed in on this phone".
class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final Profile? p = profile;
    return Container(
      padding: EdgeInsets.fromLTRB(
        DsSpace.gutter,
        MediaQuery.paddingOf(context).top + DsSpace.md,
        DsSpace.gutter,
        DsSpace.xl,
      ),
      decoration: const BoxDecoration(
        color: DsColors.deep,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              header: true,
              child: Text(
                'Profile',
                style: DsText.section.copyWith(color: DsColors.white),
              ),
            ),
          ),
          const SizedBox(height: DsSpace.md),
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DsColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: DsColors.deepRaised, width: 5),
            ),
            child: p == null
                ? const Icon(DsIcons.profile, size: 32, color: DsColors.primary)
                : Text(
                    initialsOf(p.fullName),
                    style: DsText.title.copyWith(color: DsColors.primary),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            p?.fullName ?? ' ',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DsText.title.copyWith(color: DsColors.white, fontSize: 20),
          ),
          if (p != null)
            Text(
              'Employee · ${p.userCode}',
              style: DsText.caption.copyWith(color: DsColors.skyText),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpace.md,
              vertical: 5,
            ),
            decoration: const BoxDecoration(
              color: DsColors.deepRaised,
              borderRadius: DsRadius.pill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: DsColors.liveOnDeep,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Signed in on this phone',
                  style: DsText.micro.copyWith(color: DsColors.white),
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
  const _Card({required this.children, required this.padding});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: const BoxDecoration(
      color: DsColors.white,
      borderRadius: DsRadius.large,
    ),
    child: Column(children: children),
  );
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: DsColors.text2),
          const SizedBox(width: DsSpace.md),
          Expanded(child: Text(label, style: DsText.label)),
          const SizedBox(width: DsSpace.sm),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    ),
  );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.tone,
    required this.label,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final DsStatus tone;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: DsRadius.medium,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tone == DsStatus.off ? DsColors.disabled : tone.tint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: tone.text),
            ),
            const SizedBox(width: DsSpace.md),
            Expanded(child: Text(label, style: ProfilePage._bold)),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: DsSpace.sm),
              trailing!,
            ],
            if (onTap != null) ...<Widget>[
              const SizedBox(width: DsSpace.xs),
              const Icon(DsIcons.forward, size: 20, color: DsColors.text3),
            ],
          ],
        ),
      ),
    ),
  );
}
