import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../domain/entities/live_position.dart';
import '../../../../../shared/widgets/app_status_pill.dart';
import '../controllers/admin_live_map_state.dart';

/// The key into [AppStatusColors] for a live status.
String liveStatusKey(LiveStatus status) => switch (status) {
  LiveStatus.active => 'active',
  LiveStatus.stale => 'stale',
  LiveStatus.suspect => 'suspect',
};

/// Card shown at the bottom of the live map when a dot is tapped: who it is,
/// their status in colour AND words, and how fresh the position is.
class LiveOfficerCard extends StatelessWidget {
  const LiveOfficerCard({
    super.key,
    required this.officer,
    required this.onClose,
    required this.onZoomTo,
    required this.onViewRoute,
  });

  final LiveOfficer officer;
  final VoidCallback onClose;
  final VoidCallback onZoomTo;

  /// Opens today's route of this employee.
  final VoidCallback onViewRoute;

  @override
  Widget build(BuildContext context) {
    final position = officer.position;
    final battery = position.batteryLevel;
    final accuracy = position.accuracy;

    return Container(
      key: const Key('live-officer-card'),
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary50,
                child: Text(
                  officer.initials,
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
                  children: <Widget>[
                    Text(
                      officer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title.copyWith(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (officer.employeeCode.isNotEmpty)
                      Text(
                        officer.employeeCode,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('btn-live-officer-close'),
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.neutral400,
                tooltip: 'Close',
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: AppSpacing.x3,
            runSpacing: AppSpacing.x1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              AppStatusPill(statusKey: liveStatusKey(officer.status)),
              _fact(Icons.schedule_rounded, officer.lastSeen),
              if (battery != null)
                _fact(Icons.battery_std_rounded, '$battery%'),
              if (accuracy != null)
                _fact(Icons.gps_fixed_rounded, '±${accuracy.round()} m'),
            ],
          ),
          if (officer.phoneNumber.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.x2),
            _fact(Icons.phone_outlined, officer.phoneNumber),
          ],
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.x2,
            children: <Widget>[
              TextButton.icon(
                key: const Key('btn-live-officer-route'),
                onPressed: onViewRoute,
                icon: const Icon(Icons.alt_route_rounded, size: 18),
                label: Text('View route', style: _actionStyle),
              ),
              TextButton.icon(
                key: const Key('btn-live-officer-zoom'),
                onPressed: onZoomTo,
                icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                label: Text('Zoom to location', style: _actionStyle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static final TextStyle _actionStyle = AppTypography.label.copyWith(
    color: AppColors.primary600,
    fontWeight: FontWeight.w600,
  );

  Widget _fact(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: AppColors.neutral600),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
