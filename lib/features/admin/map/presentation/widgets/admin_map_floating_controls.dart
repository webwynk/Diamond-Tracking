import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Floating bottom telemetry indicator and map tool controls for Screen 15.
class AdminMapFloatingControls extends StatelessWidget {
  const AdminMapFloatingControls({
    super.key,
    required this.onRecenter,
    required this.onToggleLayers,
    required this.onToggleListView,
    this.isSatellite = false,
  });

  final VoidCallback onRecenter;
  final VoidCallback onToggleLayers;
  final VoidCallback onToggleListView;
  final bool isSatellite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Bottom-Left: Live Capsule + Legal Mapbox Attribution
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.fullAll,
                  border: Border.all(color: AppColors.neutral200),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0C000000),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mapbox © OpenStreetMap',
                style: AppTypography.caption.copyWith(
                  fontSize: 10,
                  color: AppColors.neutral400,
                ),
              ),
            ],
          ),

          // 2. Bottom-Right: 3 Circular Map Tool Buttons
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Button 1: Re-center GPS
              _buildFloatingCircleBtn(
                key: const Key('btn-admin-map-recenter'),
                icon: Icons.my_location_rounded,
                iconColor: AppColors.primary600,
                tooltip: 'Re-center Live GPS',
                onTap: onRecenter,
              ),
              const SizedBox(height: AppSpacing.x2),

              // Button 2: Map layers toggle
              _buildFloatingCircleBtn(
                key: const Key('btn-admin-map-layers'),
                icon: Icons.layers_rounded,
                iconColor: isSatellite
                    ? AppColors.primary600
                    : AppColors.textSecondary,
                tooltip: 'Map layers toggle',
                onTap: onToggleLayers,
              ),
              const SizedBox(height: AppSpacing.x2),

              // Button 3: List-view toggle
              _buildFloatingCircleBtn(
                key: const Key('btn-admin-map-list-view'),
                icon: Icons.format_list_bulleted_rounded,
                iconColor: AppColors.textSecondary,
                tooltip: 'Switch to list view',
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
