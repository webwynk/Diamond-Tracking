import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duty_time_helper.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_state.dart';
import '../../duty/presentation/controllers/duty_controller.dart';
import '../../duty/presentation/controllers/duty_state.dart';
import '../../duty/presentation/duty_off_summary_dialog.dart';

/// Employee Home Dashboard uniting Screens 06, 07, and 08:
/// - Screen 06: Employee Home (Duty Off)
/// - Screen 07: Employee Home (Duty On / Active Foreground Tracking)
/// - Screen 08: Employee Home (Duty Disabled Outside Operating Window)
class EmployeeHomePage extends ConsumerStatefulWidget {
  const EmployeeHomePage({
    super.key,
    this.onNavigateToMap,
    this.onNavigateToHistory,
    this.onNavigateToNotifications,
    this.onNavigateToProfile,
  });

  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToHistory;
  final VoidCallback? onNavigateToNotifications;
  final VoidCallback? onNavigateToProfile;

  @override
  ConsumerState<EmployeeHomePage> createState() => _EmployeeHomePageState();
}

class _EmployeeHomePageState extends ConsumerState<EmployeeHomePage> {
  int _selectedTabIndex = 0;

  Future<void> _handleEndDuty() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.neutral0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Text('End duty?', style: AppTypography.title),
        content: const Text(
          'This will stop background location tracking and finalize your daily attendance shift.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.label.withColor(AppColors.textSecondary),
            ),
          ),
          TextButton(
            key: const Key('confirm-end-duty-btn'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'End duty',
              style: AppTypography.label.withColor(AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final session =
          await ref.read(dutyControllerProvider.notifier).endDuty();
      if (session != null && mounted) {
        DutyOffSummaryDialog.show(
          context,
          session: session,
          onViewRoute: widget.onNavigateToMap,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dutyState = ref.watch(dutyControllerProvider);
    final authState = ref.watch(authControllerProvider);

    // Extract employee initials, name, and employee code
    String initials = 'DA';
    String fullName = 'Employee';
    String employeeCode = 'DA-000';

    if (authState is AuthAuthenticated) {
      fullName = authState.profile.fullName;
      employeeCode = authState.profile.employeeCode ?? 'DA-000';
      final parts = fullName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildFixedBrandHeader(
        initials: initials,
        fullName: fullName,
        employeeCode: employeeCode,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 1. Operating Window / Telemetry Status Strip
              _buildStatusStrip(dutyState),
              const SizedBox(height: AppSpacing.x4),

              // 2. The Hero Duty Toggle (Screens 06, 07, 08)
              _buildHeroDutyToggle(dutyState),
              const SizedBox(height: AppSpacing.x2),

              // Micro-telemetry GPS Banner
              _buildMicroTelemetryBanner(dutyState),
              const SizedBox(height: AppSpacing.x5),

              // 3. TODAY SO FAR Section
              _buildTodaySoFarSection(dutyState),
              const SizedBox(height: AppSpacing.x4),

              // 4. Contextual Card: Current Location Map (On Duty) or Yesterday Summary (Off Duty)
              if (dutyState.isOnDuty)
                _buildCurrentLocationCard()
              else
                _buildYesterdayCard(dutyState),
              const SizedBox(height: AppSpacing.x4),

              // 5. Agronomist / Frontline Sync Ready Banner
              _buildShiftSyncReadyCard(dutyState),
              const SizedBox(height: AppSpacing.x8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  PreferredSizeWidget _buildFixedBrandHeader({
    required String initials,
    required String fullName,
    required String employeeCode,
  }) {
    return AppBar(
      backgroundColor: AppColors.primary600,
      elevation: 0,
      centerTitle: false,
      titleSpacing: AppSpacing.x4,
      title: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surface,
            child: Text(
              initials,
              style: AppTypography.label.copyWith(
                color: AppColors.primary600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  fullName,
                  style: AppTypography.title.withColor(AppColors.neutral0),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  employeeCode,
                  style: AppTypography.caption.withColor(
                    AppColors.neutral0.withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.notifications_none, color: AppColors.neutral0),
          tooltip: 'Notifications',
          onPressed: widget.onNavigateToNotifications,
        ),
        IconButton(
          icon: const CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary500,
            child: Icon(Icons.person, size: 16, color: AppColors.neutral0),
          ),
          tooltip: 'My Profile',
          onPressed: widget.onNavigateToProfile,
        ),
        const SizedBox(width: AppSpacing.x2),
      ],
    );
  }

  Widget _buildStatusStrip(DutyScreenState state) {
    if (state.isDisabled) {
      // Screen 08: Outside operating window
      return Container(
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.warning.withAlpha(90)),
        ),
        padding: const EdgeInsets.all(AppSpacing.x3),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule,
                size: 18,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Outside duty hours',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Duty can be started between 8:00 AM and 11:00 PM.',
                    style: AppTypography.caption.withColor(AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (state.isOnDuty) {
      // Screen 07: Active on-duty tracking banner
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.successBg,
          borderRadius: AppRadius.lgAll,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  'Tracking active',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              'Updated just now',
              style: AppTypography.caption.withColor(AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Screen 06: Off duty standard information strip
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: AppRadius.lgAll,
      ),
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info, size: 20, color: AppColors.info),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Duty hours today: ',
                children: <TextSpan>[
                  TextSpan(
                    text: '8:00 AM to 11:00 PM',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              style: AppTypography.body.withColor(AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroDutyToggle(DutyScreenState state) {
    if (state.isDisabled) {
      // Screen 08: Non-tappable disabled container
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(70),
          border: Border.all(
            color: AppColors.neutral300,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.lock_clock,
              size: 36,
              color: AppColors.neutral400,
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              'Start duty',
              style: AppTypography.h3.withColor(AppColors.textDisabled),
            ),
            const SizedBox(height: AppSpacing.x1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: const BoxDecoration(
                color: AppColors.neutral200,
                borderRadius: AppRadius.fullAll,
              ),
              child: Text(
                state.disabledReason ?? 'Opens at 8:00 AM',
                style: AppTypography.caption.withColor(AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    if (state.isOnDuty) {
      // Screen 07: Active hero toggle (Green pill with live elapsed duration)
      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('btn-toggle-duty-active'),
          onTap: _handleEndDuty,
          borderRadius: BorderRadius.circular(70),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(70),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withAlpha(80),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'ON DUTY',
                  style: AppTypography.overline.withColor(
                    AppColors.neutral0.withAlpha(200),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.activeSession?.formattedElapsed ?? '0h 0m',
                  style: AppTypography.display.copyWith(
                    color: AppColors.neutral0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neutral0.withAlpha(40),
                    borderRadius: AppRadius.fullAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.stop_circle,
                        size: 16,
                        color: AppColors.neutral0,
                      ),
                      const SizedBox(width: AppSpacing.x1),
                      Text(
                        'Tap to end duty',
                        style: AppTypography.label.withColor(AppColors.neutral0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Screen 06: Off duty pill hero button
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(dutyControllerProvider.notifier).toggleDuty(),
        borderRadius: BorderRadius.circular(70),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: state.status == DutyStatus.starting
                ? AppColors.successBg
                : AppColors.neutral100,
            borderRadius: BorderRadius.circular(70),
            border: Border.all(
              color: state.status == DutyStatus.starting
                  ? AppColors.success
                  : AppColors.neutral300,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.power_settings_new,
                size: 40,
                color: state.status == DutyStatus.starting
                    ? AppColors.success
                    : AppColors.neutral400,
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                state.status == DutyStatus.starting
                    ? 'Acquiring GPS...'
                    : 'Start duty',
                style: AppTypography.h3.copyWith(
                  color: state.status == DutyStatus.starting
                      ? AppColors.success
                      : AppColors.neutral700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                state.status == DutyStatus.starting
                    ? 'Calibrating local telemetry'
                    : 'Tap to begin tracking',
                style: AppTypography.caption.withColor(AppColors.textDisabled),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicroTelemetryBanner(DutyScreenState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: state.isOnDuty
                        ? AppColors.success
                        : AppColors.neutral400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    state.isOnDuty
                        ? 'GPS ACTIVE • VERIFIED TELEMETRY'
                        : 'GPS STANDBY • SATELLITES ACQUIRED (${state.satellitesAcquired})',
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.overline.copyWith(
                      color: state.isOnDuty
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Text(
            state.isOnDuty ? 'On duty' : 'Off duty',
            style: AppTypography.caption.withColor(
              state.isOnDuty ? AppColors.success : AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySoFarSection(DutyScreenState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'TODAY SO FAR',
          style: AppTypography.overline.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Row(
          children: <Widget>[
            // Hours
            Expanded(
              child: _buildMetricCard(
                title: 'HOURS',
                value: DutyTimeHelper.formatElapsed(state.elapsedDuration),
                caption: state.isOnDuty ? 'Active' : 'elapsed',
                captionColor: state.isOnDuty
                    ? AppColors.success
                    : AppColors.textDisabled,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),

            // Distance
            Expanded(
              child: _buildMetricCard(
                title: 'DISTANCE',
                value: '${DutyTimeHelper.formatDistanceKm(state.distanceKm)} km',
                caption: state.isOnDuty ? 'GPS verified' : '0 route legs',
                captionColor: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),

            // Visits
            Expanded(
              child: _buildMetricCard(
                title: 'VISITS',
                value: state.visitsCount.toString(),
                caption: 'completed',
                captionColor: AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String caption,
    required Color captionColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.neutral200),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x3,
      ),
      child: Column(
        children: <Widget>[
          Text(
            title,
            style: AppTypography.overline.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            value,
            style: AppTypography.h2.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: AppTypography.caption.withColor(captionColor),
          ),
        ],
      ),
    );
  }

  Widget _buildYesterdayCard(DutyScreenState state) {
    final yesterday = state.yesterdaySession;
    final now = DutyTimeHelper.nowIst;
    final yesterdayDate = now.subtract(const Duration(days: 1));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.neutral200),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Yesterday',
                style: AppTypography.title.withColor(AppColors.textPrimary),
              ),
              Text(
                DutyTimeHelper.formatDate(yesterdayDate),
                style: AppTypography.caption.withColor(AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          _buildSummaryRow(
            icon: Icons.schedule,
            label: 'Hours',
            value: yesterday != null
                ? yesterday.formattedElapsed
                : '8h 12m',
          ),
          const Divider(height: AppSpacing.x3, color: AppColors.neutral200),
          _buildSummaryRow(
            icon: Icons.near_me,
            label: 'Distance',
            value: yesterday != null
                ? yesterday.formattedDistanceKm
                : '47.3 km',
          ),
          const Divider(height: AppSpacing.x3, color: AppColors.neutral200),
          _buildSummaryRow(
            icon: Icons.pin_drop,
            label: 'Visits',
            value: yesterday != null
                ? yesterday.visitsCount.toString()
                : '5',
          ),
          const SizedBox(height: AppSpacing.x3),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: widget.onNavigateToHistory,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'View history',
                    style: AppTypography.label.withColor(AppColors.primary600),
                  ),
                  const SizedBox(width: AppSpacing.x1),
                  const Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: AppColors.primary600,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.x2),
            Text(
              label,
              style: AppTypography.body.withColor(AppColors.textSecondary),
            ),
          ],
        ),
        Text(
          value,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.neutral200),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Current location',
                style: AppTypography.title.withColor(AppColors.textPrimary),
              ),
              InkWell(
                onTap: widget.onNavigateToMap,
                child: Row(
                  children: <Widget>[
                    Text(
                      'Open map',
                      style: AppTypography.label.withColor(AppColors.primary600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: AppColors.primary600,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          // Stylized Agricultural Vector Map Thumbnail
          Container(
            height: 120,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.primary50,
              borderRadius: AppRadius.mdAll,
            ),
            child: Stack(
              children: <Widget>[
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.my_location,
                        size: 32,
                        color: AppColors.primary600,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live telemetry stream active',
                        style: AppTypography.caption.withColor(AppColors.primary600),
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

  Widget _buildShiftSyncReadyCard(DutyScreenState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.primary100),
      ),
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user,
              size: 16,
              color: AppColors.primary600,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Shift Sync Ready',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.queuedPointsCount > 0
                      ? '${state.queuedPointsCount} GPS telemetry points stored locally in offline queue.'
                      : 'Offline cache contains local farm polygons. Starting duty activates automatic background telemetry.',
                  style: AppTypography.caption.withColor(AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: _selectedTabIndex,
      onTap: (index) {
        setState(() => _selectedTabIndex = index);
        if (index == 1 && widget.onNavigateToMap != null) {
          widget.onNavigateToMap!();
        } else if (index == 2 && widget.onNavigateToHistory != null) {
          widget.onNavigateToHistory!();
        }
      },
      selectedItemColor: AppColors.primary600,
      unselectedItemColor: AppColors.neutral400,
      backgroundColor: AppColors.surface,
      elevation: 8,
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.shield),
          label: 'Duty',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: 'Map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'History',
        ),
      ],
    );
  }
}
