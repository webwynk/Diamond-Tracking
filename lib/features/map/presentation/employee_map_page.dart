import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/constants/map_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duty_time_helper.dart';
import '../../../core/utils/map_support.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../duty/presentation/controllers/duty_controller.dart';
import '../../duty/presentation/controllers/duty_state.dart';
import '../../visits/presentation/visit_capture_sheet.dart';

/// Screen 09: Employee Live Map.
///
/// Displays the employee's live position, today's route trail, floating telemetry
/// HUD, re-centering GPS controls, and the quick "Add visit" action sheet.
/// Adheres strictly to PRD F5 and docs/07-MAPLIBRE-BEST-PRACTICES.md.
class EmployeeMapPage extends ConsumerStatefulWidget {
  const EmployeeMapPage({super.key, this.onAddVisitPressed});

  final VoidCallback? onAddVisitPressed;

  @override
  ConsumerState<EmployeeMapPage> createState() => _EmployeeMapPageState();
}

class _EmployeeMapPageState extends ConsumerState<EmployeeMapPage> {
  MapLibreMapController? _mapController;
  String _currentStyle = MapConstants.defaultStyle;
  bool _isRecentering = false;

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  Future<void> _recenterMap() async {
    final location = ref.read(dutyControllerProvider).lastLocation;
    if (location == null) {
      AppSnackbar.show(context, message: 'Waiting for a GPS fix.');
      return;
    }

    setState(() => _isRecentering = true);
    try {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(location.latitude, location.longitude),
          15.0,
        ),
      );
    } catch (_) {
      // Ignored if map is not attached
    } finally {
      if (mounted) {
        setState(() => _isRecentering = false);
      }
    }
  }

  Future<void> _openVisitCapture(DutyScreenState state) async {
    final session = state.activeSession;
    final location = state.lastLocation;
    if (session == null || location == null) {
      AppSnackbar.show(
        context,
        message: 'Start duty and wait for a GPS fix to add a visit.',
      );
      return;
    }
    final saved = await VisitCaptureSheet.show(
      context,
      dutySessionId: session.id,
      employeeId: session.employeeId,
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
    );
    if (saved == true && mounted) {
      ref.read(dutyControllerProvider.notifier).refresh();
    }
  }

  void _toggleMapStyle() {
    setState(() {
      _currentStyle = _currentStyle == MapConstants.defaultStyle
          ? MapConstants.brightStyle
          : MapConstants.defaultStyle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dutyState = ref.watch(dutyControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        style: AppTopBarStyle.brand,
        title: 'My location',
        actions: <Widget>[
          _buildDutyBadge(dutyState),
          const SizedBox(width: AppSpacing.x3),
        ],
      ),
      body: Stack(
        children: <Widget>[
          // 1. Full Bleed Map Layer
          Positioned.fill(child: _buildMapCanvas()),

          // 2. Floating Telemetry Chip
          Positioned(
            top: AppSpacing.x2,
            left: 0,
            right: 0,
            child: Center(child: _buildTelemetryToast(dutyState)),
          ),

          // 3. Mid-Screen Controls & Legal Attribution Row
          Positioned(
            left: AppSpacing.x4,
            right: AppSpacing.x4,
            bottom: 236, // Pinned just above the bottom sheet
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                // Mandatory OpenStreetMap & OpenFreeMap Attribution
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x2,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withAlpha(220),
                    borderRadius: AppRadius.smAll,
                    border: Border.all(color: AppColors.neutral200),
                  ),
                  child: Text(
                    MapConstants.attribution,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                // Right Floating Action Controls
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _buildFloatingCircleButton(
                      key: const Key('btn-recenter'),
                      icon: Icons.my_location,
                      color: _isRecentering
                          ? AppColors.primary700
                          : AppColors.primary600,
                      tooltip: 'Recenter map',
                      onPressed: _recenterMap,
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    _buildFloatingCircleButton(
                      key: const Key('btn-layers'),
                      icon: Icons.layers,
                      color: AppColors.neutral600,
                      tooltip: 'Change map style',
                      onPressed: _toggleMapStyle,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Pinned Bottom Sheet (Today's Telemetry + Add Visit CTA)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomSheet(dutyState),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCanvas() {
    if (!MapSupport.isNativeMapAvailable) {
      return _buildVectorFallbackCanvas();
    }

    return MapLibreMap(
      key: ValueKey(_currentStyle),
      styleString: _currentStyle,
      initialCameraPosition: const CameraPosition(
        target: LatLng(
          MapConstants.defaultLatitude,
          MapConstants.defaultLongitude,
        ),
        zoom: MapConstants.defaultZoom,
      ),
      onMapCreated: _onMapCreated,
      myLocationEnabled: true,
      myLocationRenderMode: MyLocationRenderMode.normal,
      attributionButtonMargins: const Point<num>(
        -100,
        -100,
      ), // Custom attribution rendered in UI
      compassEnabled: false,
    );
  }

  Widget _buildVectorFallbackCanvas() {
    return Container(
      color: AppColors.neutral100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.map_outlined,
              size: 48,
              color: AppColors.primary400,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'MapLibre Vector Cartography',
              style: AppTypography.title.withColor(AppColors.primary600),
            ),
            const SizedBox(height: 2),
            Text(
              '${MapConstants.providerName} Tiles (${MapConstants.defaultLatitude}, ${MapConstants.defaultLongitude})',
              style: AppTypography.caption.withColor(AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyBadge(DutyScreenState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: state.isOnDuty ? AppColors.successBg : AppColors.neutral100,
        borderRadius: AppRadius.fullAll,
        border: Border.all(
          color: state.isOnDuty
              ? AppColors.success.withAlpha(50)
              : AppColors.neutral300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: state.isOnDuty ? AppColors.success : AppColors.neutral400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            state.isOnDuty ? 'On duty' : 'Off duty',
            style: AppTypography.label.copyWith(
              color: state.isOnDuty ? AppColors.success : AppColors.neutral600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryToast(DutyScreenState state) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(240),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.satellite_alt,
            size: 15,
            color: AppColors.primary600,
          ),
          const SizedBox(width: 6),
          Text(
            state.lastLocation == null
                ? 'Waiting for GPS…'
                : 'GPS accuracy ±${state.lastLocation!.accuracy.round()} m',
            style: AppTypography.caption.withColor(AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCircleButton({
    required Key key,
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.neutral200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(DutyScreenState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: AppColors.neutral200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(
        left: AppSpacing.x4,
        right: AppSpacing.x4,
        top: AppSpacing.x3,
        bottom: AppSpacing.x6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Drag handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutral300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),

          // Overline
          Text(
            'TODAY',
            style: AppTypography.overline.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),

          // 3-Column Telemetry Stat Block
          Container(
            decoration: BoxDecoration(
              color: AppColors.neutral50,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: AppColors.neutral200),
            ),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
            child: Row(
              children: <Widget>[
                // Hours
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(
                        DutyTimeHelper.formatElapsed(state.elapsedDuration),
                        style: AppTypography.h2.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hours',
                        style: AppTypography.caption.withColor(
                          AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.neutral200),

                // Distance
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(
                        DutyTimeHelper.formatDistanceKm(state.distanceKm),
                        style: AppTypography.h2.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'km',
                        style: AppTypography.caption.withColor(
                          AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.neutral200),

                // Visits
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(
                        state.visitsCount.toString(),
                        style: AppTypography.h2.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Visits',
                        style: AppTypography.caption.withColor(
                          AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x4),

          // Add Visit CTA Button
          AppButton(
            key: const Key('btn-add-visit'),
            label: 'Add visit',
            icon: const Icon(
              Icons.photo_camera,
              size: 20,
              color: AppColors.neutral0,
            ),
            isFullWidth: true,
            onPressed:
                widget.onAddVisitPressed ?? () => _openVisitCapture(state),
          ),
        ],
      ),
    );
  }
}
