import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_live_map_state.dart';

/// Small pill telling the admin whether the map is live, so a lost connection
/// never looks like "nobody is working". Colour AND words.
class LiveConnectionBadge extends StatelessWidget {
  const LiveConnectionBadge({super.key, required this.connection});

  final LiveConnection connection;

  @override
  Widget build(BuildContext context) {
    final (
      Color colour,
      Color background,
      String label,
      IconData icon,
    ) = switch (connection) {
      LiveConnection.live => (
        AppColors.success,
        AppColors.successBg,
        'Live',
        Icons.sensors_rounded,
      ),
      LiveConnection.connecting => (
        AppColors.info,
        AppColors.infoBg,
        'Connecting…',
        Icons.sync_rounded,
      ),
      LiveConnection.offline => (
        AppColors.warningText,
        AppColors.warningBg,
        'Offline · showing last known positions',
        Icons.cloud_off_rounded,
      ),
    };

    return Container(
      key: const Key('live-connection-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: colour.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: colour),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: colour,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
