import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';

/// Floating map tool buttons for the live map: zoom to everyone, show the list.
class AdminMapFloatingControls extends StatelessWidget {
  const AdminMapFloatingControls({
    super.key,
    required this.onRecenter,
    required this.onToggleListView,
  });

  final VoidCallback onRecenter;
  final VoidCallback onToggleListView;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Map tool buttons (bottom-right)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Button 1: fit the camera to everyone on duty
              _buildFloatingCircleBtn(
                key: const Key('btn-admin-map-recenter'),
                icon: Icons.my_location_rounded,
                iconColor: AppColors.primary600,
                tooltip: 'Zoom to everyone on duty',
                onTap: onRecenter,
              ),
              const SizedBox(height: AppSpacing.x2),

              // Button 2: the list alternative
              _buildFloatingCircleBtn(
                key: const Key('btn-admin-map-list-view'),
                icon: Icons.format_list_bulleted_rounded,
                iconColor: AppColors.textSecondary,
                tooltip: 'Show the list',
                onTap: onToggleListView,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCircleBtn({
    required Key key,
    required IconData icon,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.neutral200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        key: key,
        icon: Icon(icon, color: iconColor, size: 22),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}
