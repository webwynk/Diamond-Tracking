import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duty_time_helper.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../auth/presentation/auth_navigation.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_state.dart';
import '../../duty/presentation/controllers/duty_controller.dart';
import '../../duty/presentation/controllers/duty_state.dart';
import '../../history/presentation/controllers/duty_history_controller.dart';
import 'widgets/profile_details_card.dart';
import 'widgets/profile_header_hero.dart';
import 'widgets/profile_month_stats_grid.dart';
import 'widgets/profile_security_actions_card.dart';
import 'widgets/update_pin_dialog.dart';

/// Screen 13 — My Profile (Employee)
///
/// Provides employees with read-only view of their bound profile,
/// operational monthly metrics, PIN change capability, privacy details,
/// and safe logout.
class EmployeeProfilePage extends ConsumerWidget {
  const EmployeeProfilePage({super.key, this.onBack});

  final VoidCallback? onBack;

  void _showPrivacyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              color: AppColors.primary600,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.x2),
            Text(
              'Privacy & Tracking',
              style: AppTypography.title.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Diamond Agritech respects employee privacy:',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            _buildBulletPoint(
              'Location tracking is ONLY active while you are on duty (between 08:00 and 23:00 IST).',
            ),
            _buildBulletPoint(
              'Ending duty immediately terminates background GPS location collection.',
            ),
            _buildBulletPoint(
              'Curfew auto-terminates tracking at 23:00 IST every evening.',
            ),
            _buildBulletPoint(
              'Personal photos are never accessed; only in-situ camera visit proofs are stored.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Understood',
              style: AppTypography.label.copyWith(
                color: AppColors.primary600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.primary600)),
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Logging out while on duty would stop tracking and leave the office
  /// looking at a dead marker, so duty has to be turned off first.
  Future<void> _showEndDutyFirst(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('dialog-end-duty-first'),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'End duty first',
          style: AppTypography.title.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'You are on duty. Turn duty off before logging out, so your route is '
          'saved and the office is not left tracking a stopped phone.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            key: const Key('btn-end-duty-first-ok'),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'OK',
              style: AppTypography.label.copyWith(
                color: AppColors.primary600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final duty = ref.read(dutyControllerProvider.notifier);
    final check = await duty.checkBeforeSignOut();
    if (!context.mounted) return;
    if (check.onDuty) {
      await _showEndDutyFirst(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log out?',
          style: AppTypography.title.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          check.unsyncedPoints > 0
              ? '${check.unsyncedPoints} location points have not reached the '
                    'office yet and will be lost if you log out now. Connect to '
                    'the internet and try again, or log out anyway.'
              : 'Are you sure you want to log out of your Diamond Agritech employee account?',
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
            key: const Key('confirm-logout-btn'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Log out',
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
      final navigator = Navigator.of(context);
      // Delete this employee's tracking data from the phone before signing out.
      await duty.clearLocalTrackingData();
      await ref.read(authControllerProvider.notifier).signOut();
      AuthNavigation.goToLogin(navigator);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final dutyState = ref.watch(dutyControllerProvider);
    final historyState = ref.watch(dutyHistoryControllerProvider);

    // Profile Fallbacks
    String fullName = 'Employee';
    String employeeCode = '—';
    String initials = 'EM';
    String phone = '—';
    String email = '—';
    String joinedDate = '—';

    if (authState is AuthAuthenticated) {
      fullName = authState.profile.fullName;
      employeeCode = authState.profile.employeeCode ?? '—';
      phone = authState.profile.phone ?? phone;
      email = authState.profile.email ?? email;
      joinedDate = DutyTimeHelper.formatDate(authState.profile.createdAt);

      final parts = fullName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        initials = parts[0]
            .substring(0, parts[0].length >= 2 ? 2 : 1)
            .toUpperCase();
      }
    }

    final isOnDuty = dutyState.status == DutyStatus.onDuty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Hero Header Block (#016893, curved radius 24)
            ProfileHeaderHero(
              fullName: fullName,
              employeeCode: employeeCode,
              initials: initials,
              isOnDuty: isOnDuty,
              onBack: onBack,
            ),

            // 2. Overlapping Content Container (-24 dp overlap)
            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card 1 — MY DETAILS
                    ProfileDetailsCard(
                      phone: phone,
                      email: email,
                      joinedDate: joinedDate,
                    ),
                    const SizedBox(height: AppSpacing.x4),

                    // Card 2 — THIS MONTH (2x2 Stat Blocks)
                    ProfileMonthStatsGrid(
                      monthLabel: historyState.summary.periodLabel,
                      daysWorked: historyState.summary.totalDays,
                      hoursWorked: historyState.summary.totalHours,
                      distanceKm: historyState.summary.totalKm,
                      visitsCount: historyState.summary.totalVisits,
                    ),
                    const SizedBox(height: AppSpacing.x4),

                    // Card 3 — Security & Actions
                    ProfileSecurityActionsCard(
                      onChangePin: () async {
                        final updated = await UpdatePinDialog.show(
                          context,
                          onSavePin: (newPin) async {
                            final success = await ref
                                .read(authControllerProvider.notifier)
                                .completePinChange(newPin: newPin);
                            return success;
                          },
                        );

                        if (updated == true && context.mounted) {
                          AppSnackbar.show(
                            context,
                            message: 'Security PIN successfully updated.',
                          );
                        }
                      },
                      onPrivacyAndTracking: () => _showPrivacyDialog(context),
                    ),
                    const SizedBox(height: AppSpacing.x4),

                    // Action 4 — Outlined Log out Button
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        key: const Key('btn-logout'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(
                            color: AppColors.error,
                            width: 1,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.mdAll,
                          ),
                        ),
                        onPressed: () => _handleLogout(context, ref),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: Text(
                          'Log out',
                          style: AppTypography.label.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x6),

                    // Footer App Version
                    Center(
                      child: Text(
                        'Diamond Agritech · v1.0.0',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textDisabled,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
