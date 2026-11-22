import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../auth/domain/auth_status.dart';
import '../application/users_providers.dart';
import '../domain/profile.dart';
import 'log_out.dart';

/// The admin's own details, change password and log out, opened from the
/// top bar. (The employee's is ProfilePage.)
class AccountPage extends ConsumerWidget {
  const AccountPage({
    required this.changePasswordRoute,
    super.key,
    this.title = 'Profile',
  });

  final String changePasswordRoute;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Profile?> me = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: me.when(
        data: (Profile? value) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
          children: <Widget>[
            if (value != null) _Header(profile: value),
            const SizedBox(height: AppSpacing.x4),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.password_rounded),
              title: const Text('Change password'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(changePasswordRoute),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: Text(
                'Log out',
                style: AppTypography.bodyLarge.copyWith(color: AppColors.error),
              ),
              onTap: () => logOut(context, ref),
            ),
            const Divider(height: 1),
          ],
        ),
        error: (_, _) =>
            AppErrorView(onRetry: () => ref.invalidate(myProfileProvider)),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final String initial = profile.fullName.trim().isEmpty
        ? '?'
        : profile.fullName.trim()[0].toUpperCase();
    return Padding(
      padding: AppSpacing.screen,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary50,
            child: Text(
              initial,
              style: AppTypography.h2.copyWith(color: AppColors.primary700),
            ),
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(profile.fullName, style: AppTypography.h3),
                const SizedBox(height: 2),
                Text(
                  <String>[
                    'User ID ${profile.userCode}',
                    if (profile.role == AppRole.admin) 'Admin',
                  ].join(' · '),
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (profile.phone != null || profile.contactEmail != null)
                  Text(
                    <String>[?profile.phone, ?profile.contactEmail].join(' · '),
                    style: AppTypography.caption,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
