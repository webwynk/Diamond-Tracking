import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_status_pill.dart';
import '../../auth/domain/auth_status.dart';
import '../application/users_providers.dart';
import '../domain/profile.dart';
import 'account_button.dart';

/// The admin's list of users, with search and "Add user".
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  String _query = '';

  List<Profile> _filter(List<Profile> all) {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (Profile p) =>
              p.fullName.toLowerCase().contains(q) ||
              p.userCode.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Profile>> users = ref.watch(usersListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: const <Widget>[AccountButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.adminUserNew),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add user'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x2,
              AppSpacing.x4,
              AppSpacing.x2,
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search name or user ID',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (String v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: users.when(
              data: (List<Profile> all) => RefreshIndicator(
                onRefresh: () => ref.refresh(usersListProvider.future),
                child: _list(_filter(all), hasAny: all.isNotEmpty),
              ),
              error: (_, _) => AppErrorView(
                onRetry: () => ref.invalidate(usersListProvider),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<Profile> shown, {required bool hasAny}) {
    if (shown.isEmpty) {
      return ListView(
        children: <Widget>[
          const SizedBox(height: AppSpacing.x8),
          AppEmptyState(
            title: hasAny ? 'No match' : 'No users yet',
            description: hasAny
                ? 'No user has that name or user ID.'
                : 'Add your first user with the button below.',
            icon: Icons.group_rounded,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: shown.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int i) => _UserTile(shown[i]),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile(this.profile);

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: AppSizes.listRowMinHeight,
      onTap: () => context.push(Routes.adminUserEdit(profile.id)),
      leading: CircleAvatar(
        backgroundColor: profile.isActive
            ? AppColors.primary50
            : AppColors.neutral100,
        child: Icon(
          profile.role == AppRole.admin
              ? Icons.admin_panel_settings_rounded
              : Icons.person_rounded,
          color: profile.isActive ? AppColors.primary700 : AppColors.neutral400,
        ),
      ),
      title: Text(profile.fullName, style: AppTypography.title),
      subtitle: Text(
        <String>[
          profile.userCode,
          if (profile.role == AppRole.admin) 'Admin',
          if (profile.hasPhoneSignedIn) 'Signed in on a phone',
        ].join(' · '),
        style: AppTypography.caption,
      ),
      trailing: profile.isActive
          ? const Icon(Icons.chevron_right_rounded)
          : const AppStatusPill.custom(
              color: AppColors.neutral600,
              backgroundColor: AppColors.neutral100,
              label: 'Off',
            ),
    );
  }
}
