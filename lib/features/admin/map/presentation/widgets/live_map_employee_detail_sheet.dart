import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_live_map_state.dart';

/// Screen 16 — Persistent Employee Detail Sheet on the Live Telemetry Map.
///
/// Presents comprehensive field officer telemetry:
/// - Identity avatar with monogram ("SP") & contact details
/// - Live duty status pill (On duty, Stale, Needs check, Off duty, Blocked)
/// - 2x2 Telemetry Stat Grid (Duty duration, Distance today, Visits, Battery)
/// - Inline signal telemetry (Sync latency, GPS accuracy, Instant speed)
/// - Geofence proximity strip
/// - Action buttons (View profile, Route replay, Call employee)
class LiveMapEmployeeDetailSheet extends StatelessWidget {
  const LiveMapEmployeeDetailSheet({
    super.key,
    required this.officer,
    this.isModal = false,
    this.onViewProfile,
    this.onRouteView,
    this.onCallEmployee,
  });

  final MapOfficerItem officer;
  final bool isModal;
  final VoidCallback? onViewProfile;
  final VoidCallback? onRouteView;
  final VoidCallback? onCallEmployee;

  /// Convenience helper to open the sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required MapOfficerItem officer,
    VoidCallback? onViewProfile,
    VoidCallback? onRouteView,
    VoidCallback? onCallEmployee,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LiveMapEmployeeDetailSheet(
        officer: officer,
        isModal: true,
        onViewProfile: onViewProfile,
        onRouteView: onRouteView,
        onCallEmployee: onCallEmployee,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlTop,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        AppSpacing.x6,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Centered Tactile Drag Handle (32x4 dp)
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.x3),
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),

            // 2. Header Row: Avatar, Identity Metadata & Status Pill
            _buildHeaderRow(),

            const SizedBox(height: AppSpacing.x3),

            // 3. 2x2 Telemetry Stat Grid in #F8FAFC Panel
            _buildStatGrid(),

            const SizedBox(height: AppSpacing.x3),

            // 4. Live Signal Meta Row (Sync latency, GPS accuracy, Speed)
            _buildSignalMetaRow(),

            const SizedBox(height: AppSpacing.x3),

            // 5. Current Proximity Strip
            _buildProximityStrip(),

            const SizedBox(height: AppSpacing.x4),

            // 6. Action Buttons: View Profile & Route Replay
            _buildActionButtons(),

            const SizedBox(height: AppSpacing.x2),

            // 7. Tertiary Action: Call Employee
            _buildCallButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              // 48dp Circular Monogram Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary200,
                    width: 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  officer.initials,
                  style: AppTypography.title.copyWith(
                    color: AppColors.primary600,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      officer.name,
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${officer.employeeCode} · ${officer.phoneNumber}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.x2),
        // Live Duty Status Pill
        _buildStatusPill(officer.status),
      ],
    );
  }

  Widget _buildStatusPill(AdminOfficerStatus status) {
    Color bg;
    Color dotColor;
    Color textColor;
    String label;

    switch (status) {
      case AdminOfficerStatus.onDuty:
        bg = AppColors.successBg;
        dotColor = AppColors.success;
        textColor = const Color(0xFF15803D);
        label = 'On duty';
        break;
      case AdminOfficerStatus.stale:
        bg = AppColors.warningBg;
        dotColor = AppColors.warning;
        textColor = const Color(0xFFB45309);
        label = 'Stale';
        break;
      case AdminOfficerStatus.needsCheck:
        bg = AppColors.errorBg;
        dotColor = AppColors.error;
        textColor = AppColors.error;
        label = officer.isSos ? 'SOS Alert' : 'Needs check';
        break;
      case AdminOfficerStatus.offDuty:
        bg = const Color(0xFFF1F5F9);
        dotColor = AppColors.neutral400;
        textColor = AppColors.neutral600;
        label = 'Off duty';
        break;
      case AdminOfficerStatus.blocked:
        bg = const Color(0xFF1E293B);
        dotColor = Colors.white70;
        textColor = Colors.white;
        label = 'Blocked';
        break;
    }

    return Container(
      key: const Key('badge-sheet-duty-status'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: dotColor.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  key: const Key('stat-card-duty-duration'),
                  value: officer.dutyDuration,
                  subtitle: 'On duty since ${officer.dutyStartTime}',
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: _buildStatCard(
                  key: const Key('stat-card-distance-today'),
                  value: officer.distanceTodayKm,
                  subtitle: 'Distance today',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  key: const Key('stat-card-visits-today'),
                  value: '${officer.visitsToday}',
                  subtitle: 'Visits today',
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: _buildStatCard(
                  key: const Key('stat-card-battery-level'),
                  value: '${officer.batteryPercent}%',
                  subtitle: 'Battery',
                  trailingIcon: Icons.battery_charging_full_rounded,
                  iconColor: officer.batteryPercent > 20
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required Key key,
    required String value,
    required String subtitle,
    IconData? trailingIcon,
    Color? iconColor,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.7),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 4),
                Icon(
                  trailingIcon,
                  size: 18,
                  color: iconColor ?? AppColors.success,
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalMetaRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1. Sync Latency
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              officer.lastUpdated,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),

        // 2. Spatial GPS Accuracy
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.gps_fixed_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              'Accuracy ${officer.accuracyMeters} m',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),

        // 3. Instant Velocity
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.speed_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              '${officer.speedKmh} km/h',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProximityStrip() {
    return Container(
      key: const Key('strip-sheet-proximity'),
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.near_me_rounded,
            size: 20,
            color: AppColors.primary600,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              officer.proximityText,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Primary Action: View Profile
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              key: const Key('btn-sheet-view-profile'),
              onPressed: onViewProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(
                'View profile',
                style: AppTypography.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.x3),

        // Secondary Action: Route Replay / Route View
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              key: const Key('btn-sheet-route-view'),
              onPressed: onRouteView,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary600,
                side: const BorderSide(
                  color: AppColors.primary600,
                  width: 1.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.replay_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Route replay',
                    style: AppTypography.label.copyWith(
                      color: AppColors.primary600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallButton(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextButton.icon(
        key: const Key('btn-sheet-call-employee'),
        onPressed: onCallEmployee ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Dialing ${officer.phoneNumber}...'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
        icon: const Icon(
          Icons.call_rounded,
          size: 18,
          color: AppColors.textSecondary,
        ),
        label: Text(
          'Call employee',
          style: AppTypography.label.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
