import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_status_pill.dart';
import '../../../../auth/presentation/auth_navigation.dart';
import '../../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../auth/presentation/controllers/auth_state.dart';

/// Administrator Profile & Session Management Modal Bottom Sheet.
///
/// Follows docs/03-DESIGN-SYSTEM.md with 24 dp top radius, DM Sans typography,
/// clear administrative status pills, system telemetry metadata, and safe sign-out.
class AdminProfileSheet extends ConsumerWidget {
  const AdminProfileSheet({super.key});

  /// Displays the modal bottom sheet from any admin context.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => const AdminProfileSheet(),
    );
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            const SizedBox(width: AppSpacing.x2),
            Text(
              'Sign out',
              style: AppTypography.title.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end your administrator session?',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            key: const Key('confirm-admin-logout-btn'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Sign out',
              style: AppTypography.label.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Captured before the sheet closes: the sheet's own context is gone
      // once it is popped, but the navigator outlives it.
      final navigator = Navigator.of(context);
      navigator.pop();

      await ref.read(authControllerProvider.notifier).signOut();
      AuthNavigation.goToLogin(navigator);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final profile = authState is AuthAuthenticated ? authState.profile : null;
    final adminName = (profile?.fullName.trim().isNotEmpty ?? false)
        ? profile!.fullName
        : 'Administrator';
    final adminEmail = profile?.email?.trim();

    return Container(
      key: const Key('admin-profile-sheet'),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(
                    top: AppSpacing.x3,
                    bottom: AppSpacing.x2,
                  ),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral300,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),

              // Sheet Header: Title & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Admin Profile',
                    style: AppTypography.h3.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    key: const Key('btn-close-admin-profile'),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),

              // Profile Hero Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.x4),
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.primary100, width: 1),
                ),
                child: Row(
                  children: [
                    // Admin Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppColors.primary600,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.neutral0,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),

                    // Name + Email + Role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            adminName,
                            style: AppTypography.title.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (adminEmail != null && adminEmail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              adminEmail,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.x2),
                          Row(
                            children: [
                              const AppStatusPill.custom(
                                color: AppColors.success,
                                backgroundColor: AppColors.successBg,
                                label: 'ACTIVE',
                              ),
                              const SizedBox(width: AppSpacing.x2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary600.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                                child: Text(
                                  'ADMINISTRATOR',
                                  style: AppTypography.overline.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x3),

              // System & Platform Metadata Card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.neutral200, width: 1),
                ),
                child: Column(
                  children: [
                    _buildMetaTile(
                      icon: Icons.business_rounded,
                      label: 'Organization',
                      value: 'Diamond Agritech Pvt Ltd',
                    ),
                    const Divider(height: 1, color: AppColors.neutral200),
                    _buildMetaTile(
                      icon: Icons.schedule_rounded,
                      label: 'Operating Hours',
                      value: '08:00 – 23:00 IST (Server enforced)',
                    ),
                    const Divider(height: 1, color: AppColors.neutral200),
                    _buildMetaTile(
                      icon: Icons.info_outline_rounded,
                      label: 'App Version',
                      value: 'v1.0.2 (Build 3)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x4),

              // Log Out Button
              AppButton(
                key: const Key('btn-admin-logout'),
                label: 'Log out',
                variant: AppButtonVariant.destructive,
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: AppColors.neutral0,
                ),
                isFullWidth: true,
                onPressed: () => _handleSignOut(context, ref),
              ),
              const SizedBox(height: AppSpacing.x4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary600),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
