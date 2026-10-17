import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/constants/map_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/map_support.dart';

/// A real MapLibre street map (OpenFreeMap tiles) limited to India.
///
/// The camera starts on all of India and cannot be panned outside it, so an
/// admin can never lose the country. It draws no markers: whoever places this
/// widget layers their own content on top. No satellite imagery (street map
/// only, per the locked map decision) and no API key.
///
/// Where the native renderer is unavailable (widget tests, desktop) it shows a
/// plain placeholder with the same attribution.
class IndiaMap extends StatelessWidget {
  const IndiaMap({super.key, this.onMapCreated, this.onStyleLoaded});

  /// Hands back the controller once the native map exists.
  final void Function(MapLibreMapController controller)? onMapCreated;

  /// Called when the map style has finished loading (and again if it reloads).
  /// Sources and layers can only be added from here on.
  final VoidCallback? onStyleLoaded;

  /// Centre of India, used for the starting and re-centred camera.
  static const LatLng center = LatLng(22.5, 79.0);

  /// Zoom that fits the whole country on a phone screen.
  static const double initialZoom = 3.6;

  /// Smallest zoom allowed, so the world map is never pulled in.
  static const double minZoom = 3.0;

  /// Largest zoom allowed.
  static const double maxZoom = 18.0;

  /// Box around India, including the Andaman & Nicobar and Lakshadweep islands.
  static final LatLngBounds bounds = LatLngBounds(
    southwest: const LatLng(6.0, 67.5),
    northeast: const LatLng(37.5, 98.0),
  );

  /// Whether [latitude]/[longitude] lies inside [bounds].
  static bool contains(double latitude, double longitude) {
    return latitude >=
            min(bounds.southwest.latitude, bounds.northeast.latitude) &&
        latitude <= max(bounds.southwest.latitude, bounds.northeast.latitude) &&
        longitude >=
            min(bounds.southwest.longitude, bounds.northeast.longitude) &&
        longitude <=
            max(bounds.southwest.longitude, bounds.northeast.longitude);
  }

  /// Moves [controller]'s camera back to the whole-India view.
  static Future<void> recenter(MapLibreMapController? controller) async {
    await controller?.animateCamera(
      CameraUpdate.newLatLngZoom(center, initialZoom),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: MapSupport.isNativeMapAvailable
              ? MapLibreMap(
                  styleString: MapConstants.defaultStyle,
                  initialCameraPosition: const CameraPosition(
                    target: center,
                    zoom: initialZoom,
                  ),
                  cameraTargetBounds: CameraTargetBounds(bounds),
                  minMaxZoomPreference: const MinMaxZoomPreference(
                    minZoom,
                    maxZoom,
                  ),
                  onMapCreated: onMapCreated,
                  onStyleLoadedCallback: onStyleLoaded,
                  compassEnabled: false,
                  tiltGesturesEnabled: false,
                  // Credit is drawn below, so hide the plugin's own button.
                  attributionButtonMargins: const Point<num>(-100, -100),
                )
              : const ColoredBox(
                  key: Key('india-map-placeholder'),
                  color: AppColors.neutral100,
                  child: Center(
                    child: Icon(
                      Icons.map_outlined,
                      size: 48,
                      color: AppColors.neutral300,
                    ),
                  ),
                ),
        ),
        Positioned(
          left: AppSpacing.x2,
          bottom: AppSpacing.x2,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x2,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withAlpha(220),
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                MapConstants.attribution,
                key: const Key('india-map-attribution'),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
