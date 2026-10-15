import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import 'controllers/permission_controller.dart';

/// Screen 05: Permission and Battery Optimization Setup.
///
/// Ensures mandatory runtime permissions (foreground location, background
/// location "Allow all the time", and battery saver exemption) are granted
/// before the employee can begin duty tracking.
class PermissionSetupPage extends ConsumerStatefulWidget {
  const PermissionSetupPage({
    super.key,
    this.onCompleted,
    this.onBackPressed,
  });

  /// Optional callback invoked when all prerequisites are satisfied and
  /// the employee taps "Continue".
  final VoidCallback? onCompleted;

  /// Optional callback for the back navigation action.
  final VoidCallback? onBackPressed;

  @override
  ConsumerState<PermissionSetupPage> createState() =>
      _PermissionSetupPageState();
}

class _PermissionSetupPageState extends ConsumerState<PermissionSetupPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-evaluate OS permission statuses when returning from system settings.
      ref.read(permissionControllerProvider.notifier).refresh();
    }
  }

  Future<void> _showBatteryGuidanceDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          backgroundColor: AppColors.surface,
          title: Text(
            'Battery Optimization',
            style: AppTypography.h3.withColor(AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Aggressive battery savers (common on Xiaomi, Oppo, Vivo, Realme, and Samsung devices) stop tracking when your phone is locked or screen is off.',
                style: AppTypography.body.withColor(AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.x3),
              Text(
                'Please select "Allow" or set Diamond Agritech to "No restrictions" / "Unrestricted".',
                style: AppTypography.body.withColor(AppColors.textPrimary),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.label.withColor(AppColors.textSecondary),
              ),
            ),
            AppButton(
              label: 'Proceed',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(permissionControllerProvider.notifier);
      final ignored = await notifier.requestBatteryOptimization();
      if (!ignored && mounted) {
        // Fall back to opening app settings so the user can toggle manually.
        await notifier.openAppSettings();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(permissionControllerProvider);
    final notifier = ref.read(permissionControllerProvider.notifier);

    // Determine current focus step:
    // Step 1: Location access
    // Step 2: Background tracking ("Allow all the time")
    // Step 3: Battery saver exemption
    final isStep1Active = !state.isLocationGranted;
    final isStep2Active = state.isLocationGranted && !state.isBackgroundGranted;
    final isStep3Active = state.isLocationGranted &&
        state.isBackgroundGranted &&
        !state.isBatteryOptimizationIgnored;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          tooltip: 'Go back',
          onPressed: widget.onBackPressed ?? () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Before You Start',
          style: AppTypography.h3.withColor(AppColors.textPrimary),
        ),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.x4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary600,
              child: Icon(
                Icons.person,
                size: 18,
                color: AppColors.neutral0,
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.neutral200,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Explanatory Subtitle
              Text(
                'Duty tracking needs these three settings. We only record your location while you are on duty.',
                style: AppTypography.body.withColor(AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.x6),

              // Card 1: Foreground Location Access
              _buildSetupCard(
                key: const Key('card-step-1'),
                isActive: isStep1Active,
                isDone: state.isLocationGranted,
                icon: Icons.location_on,
                title: 'Location access',
                subtitle: state.isLocationGranted
                    ? 'Granted'
                    : 'Precise location needed for duty tracking.',
                iconBgColor: state.isLocationGranted
                    ? AppColors.successBg
                    : AppColors.primary50,
                iconColor: state.isLocationGranted
                    ? AppColors.success
                    : AppColors.primary600,
                onActionPressed: () => notifier.requestLocation(),
                actionLabel: 'Allow',
                isOutlinedAction: false,
              ),
              const SizedBox(height: AppSpacing.x3),

              // Card 2: Background Tracking ("Allow all the time")
              _buildSetupCard(
                key: const Key('card-step-2'),
                isActive: isStep2Active,
                isDone: state.isBackgroundGranted,
                icon: Icons.schedule,
                title: 'Allow all the time',
                subtitle: state.isBackgroundGranted
                    ? 'Granted'
                    : 'Needed so tracking continues when your screen is off.',
                iconBgColor: state.isBackgroundGranted
                    ? AppColors.successBg
                    : AppColors.infoBg,
                iconColor: state.isBackgroundGranted
                    ? AppColors.success
                    : AppColors.info,
                onActionPressed: () => notifier.requestBackgroundLocation(),
                actionLabel: 'Allow',
                isOutlinedAction: false,
              ),
              const SizedBox(height: AppSpacing.x3),

              // Card 3: Battery Optimization Exemption
              _buildSetupCard(
                key: const Key('card-step-3'),
                isActive: isStep3Active,
                isDone: state.isBatteryOptimizationIgnored,
                icon: Icons.battery_charging_full,
                title: 'Disable battery saver',
                subtitle: state.isBatteryOptimizationIgnored
                    ? 'Optimized for field duty'
                    : 'Your phone may stop tracking without this.',
                iconBgColor: state.isBatteryOptimizationIgnored
                    ? AppColors.successBg
                    : AppColors.warningBg,
                iconColor: state.isBatteryOptimizationIgnored
                    ? AppColors.success
                    : AppColors.warning,
                onActionPressed: _showBatteryGuidanceDialog,
                actionLabel: 'Open',
                isOutlinedAction: true,
              ),
              const SizedBox(height: AppSpacing.x4),

              // OEM Aggressive OS Battery Management Banner
              Container(
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(
                    color: AppColors.warning.withAlpha(90),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Text(
                        'On Xiaomi, Oppo, Vivo and Realme phones this step is essential, or your duty record may have gaps.',
                        style: AppTypography.body.withColor(AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x8),

              // Bottom Action Section
              AppButton(
                key: const Key('btn-continue'),
                label: 'Continue',
                isFullWidth: true,
                onPressed: state.allRequirementsSatisfied
                    ? (widget.onCompleted ?? () => Navigator.of(context).maybePop(true))
                    : null,
                disabledReason: state.allRequirementsSatisfied
                    ? null
                    : 'Complete all three steps to continue.',
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                state.allRequirementsSatisfied
                    ? 'All requirements satisfied. You are ready to start.'
                    : 'Complete all three steps to continue.',
                key: const Key('caption-continue'),
                textAlign: TextAlign.center,
                style: state.allRequirementsSatisfied
                    ? AppTypography.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      )
                    : AppTypography.caption.withColor(AppColors.textDisabled),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupCard({
    required Key key,
    required bool isActive,
    required bool isDone,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onActionPressed,
    required String actionLabel,
    required bool isOutlinedAction,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: isActive ? AppColors.primary600 : AppColors.neutral200,
          width: isActive ? 2.0 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Row(
        children: <Widget>[
          // Icon badge circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),

          // Title & status subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTypography.title.withColor(AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.body.withColor(AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),

          // Trailing action or checkmark
          if (isDone)
            const Icon(
              Icons.check_circle,
              size: 24,
              color: AppColors.success,
            )
          else if (isOutlinedAction)
            OutlinedButton(
              onPressed: onActionPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(68, 36),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                foregroundColor: AppColors.primary600,
                side: const BorderSide(
                  color: AppColors.primary600,
                  width: 1.5,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.mdAll,
                ),
              ),
              child: Text(
                actionLabel,
                style: AppTypography.label.withColor(AppColors.primary600),
              ),
            )
          else
            ElevatedButton(
              onPressed: onActionPressed,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(68, 36),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                backgroundColor: AppColors.primary600,
                foregroundColor: AppColors.neutral0,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: Text(
                actionLabel,
                style: AppTypography.label.withColor(AppColors.neutral0),
              ),
            ),
        ],
      ),
    );
  }
}
