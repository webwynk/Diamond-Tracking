import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_place_form_state.dart';

/// Lower 45% configuration bottom sheet for Screen 25 Create / Edit Place (Admin).
class AdminPlaceFormSheet extends StatelessWidget {
  const AdminPlaceFormSheet({
    super.key,
    required this.nameController,
    required this.selectedType,
    required this.radiusMeters,
    required this.coordinatesText,
    required this.isActive,
    required this.errorMessage,
    required this.onTypeChanged,
    required this.onRadiusChanged,
    required this.onActiveChanged,
    required this.onCopyCoordinates,
  });

  final TextEditingController nameController;
  final PlaceFormType selectedType;
  final double radiusMeters;
  final String coordinatesText;
  final bool isActive;
  final String? errorMessage;
  final ValueChanged<PlaceFormType> onTypeChanged;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onCopyCoordinates;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('admin-place-form-sheet'),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border(
          top: BorderSide(color: AppColors.neutral200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        12,
        AppSpacing.x4,
        AppSpacing.x5,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Center Drag Handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral300,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x3),

              // Field 1: Place Name
              Text(
                'Place name',
                style: AppTypography.label.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: errorMessage != null
                        ? AppColors.error
                        : AppColors.neutral300,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                alignment: Alignment.centerLeft,
                child: TextField(
                  key: const Key('input-place-name'),
                  controller: nameController,
                  style: AppTypography.body.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  errorMessage!,
                  key: const Key('text-form-error'),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.x3),

              // Field 2: Place Type Chips
              Text(
                'Type',
                style: AppTypography.label.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _buildTypeChip(
                      type: PlaceFormType.farm,
                      label: 'Farm',
                      icon: Icons.eco_rounded,
                      chipKey: const Key('chip-type-farm'),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    _buildTypeChip(
                      type: PlaceFormType.dealer,
                      label: 'Dealer',
                      icon: Icons.storefront_rounded,
                      chipKey: const Key('chip-type-dealer'),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    _buildTypeChip(
                      type: PlaceFormType.office,
                      label: 'Office',
                      icon: Icons.corporate_fare_rounded,
                      chipKey: const Key('chip-type-office'),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    _buildTypeChip(
                      type: PlaceFormType.warehouse,
                      label: 'Warehouse',
                      icon: Icons.warehouse_rounded,
                      chipKey: const Key('chip-type-warehouse'),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    _buildTypeChip(
                      type: PlaceFormType.other,
                      label: 'Other',
                      icon: Icons.location_on_rounded,
                      chipKey: const Key('chip-type-other'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x3),

              // Field 3: Radius Slider Module
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Radius',
                    style: AppTypography.label.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                  Text(
                    '${radiusMeters.round()} m',
                    key: const Key('text-radius-value'),
                    style: AppTypography.label.copyWith(
                      color: AppColors.primary600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary600,
                  inactiveTrackColor: AppColors.neutral200,
                  trackHeight: 6,
                  thumbColor: AppColors.primary600,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 18,
                  ),
                ),
                child: Slider(
                  key: const Key('slider-geofence-radius'),
                  value: radiusMeters,
                  min: 50.0,
                  max: 2000.0,
                  onChanged: onRadiusChanged,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    '50 m',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral400,
                    ),
                  ),
                  Text(
                    '2000 m',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),

              // Field 4: Notice / Operational Warning Strip (#E0F2FE)
              Container(
                key: const Key('photo-prompt-banner'),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.x3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.info,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.x2 + 2),
                    Expanded(
                      child: Text(
                        'Employees are asked for a photo when they enter this circle.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.neutral900,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x3),

              // Field 5: Coordinates Readout
              Text(
                'Coordinates',
                style: AppTypography.label.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.neutral200, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      coordinatesText,
                      key: const Key('text-coordinates-value'),
                      style: AppTypography.body.copyWith(
                        color: AppColors.neutral600,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      key: const Key('btn-copy-coordinates'),
                      onPressed: onCopyCoordinates,
                      icon: const Icon(
                        Icons.content_copy_rounded,
                        color: AppColors.primary600,
                        size: 18,
                      ),
                      splashRadius: 18,
                      tooltip: 'Copy coordinates to clipboard',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x3),

              // Field 6: Active Status Toggle Row
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.neutral100, width: 1),
                  ),
                ),
                padding: const EdgeInsets.only(top: AppSpacing.x2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Active',
                            style: AppTypography.body.copyWith(
                              color: AppColors.neutral900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Raise events when employees arrive',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.neutral500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Switch(
                      key: const Key('switch-place-active'),
                      value: isActive,
                      onChanged: onActiveChanged,
                      activeThumbColor: AppColors.primary600,
                      activeTrackColor: AppColors.primary600.withValues(alpha: 0.38),
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

  Widget _buildTypeChip({
    required PlaceFormType type,
    required String label,
    required IconData icon,
    required Key chipKey,
  }) {
    final isSelected = selectedType == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: chipKey,
        onTap: () => onTypeChanged(type),
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary600 : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: isSelected ? AppColors.primary600 : AppColors.neutral300,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.neutral0 : AppColors.neutral500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: isSelected ? AppColors.neutral0 : AppColors.neutral900,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
