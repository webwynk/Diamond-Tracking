import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../shared/widgets/india_map.dart';

/// Where a visit happened: the street map with one pin, centred on it.
///
/// Uses the same map as the rest of the admin app (MapLibre + OpenFreeMap, no
/// key, no satellite). Where the native map cannot run (widget tests, desktop)
/// [IndiaMap] shows its plain placeholder instead.
class AdminVisitMapCard extends StatefulWidget {
  const AdminVisitMapCard({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  static const double height = 220;
  static const double zoom = 16;

  final double latitude;
  final double longitude;

  @override
  State<AdminVisitMapCard> createState() => _AdminVisitMapCardState();
}

class _AdminVisitMapCardState extends State<AdminVisitMapCard> {
  static const String _source = 'visit-pin';
  static const String _layer = 'visit-pin-layer';

  MapLibreMapController? _controller;

  bool get _hasValidCoordinates =>
      widget.latitude >= -90.0 &&
      widget.latitude <= 90.0 &&
      widget.longitude >= -180.0 &&
      widget.longitude <= 180.0 &&
      !(widget.latitude == 0.0 && widget.longitude == 0.0);

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    try {
      try {
        await controller.removeLayer(_layer);
      } catch (_) {}
      try {
        await controller.removeSource(_source);
      } catch (_) {}

      await controller.addSource(
        _source,
        GeojsonSourceProperties(
          data: <String, dynamic>{
            'type': 'Feature',
            'geometry': <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[widget.longitude, widget.latitude],
            },
            'properties': <String, dynamic>{},
          },
        ),
      );
      await controller.addCircleLayer(
        _source,
        _layer,
        CircleLayerProperties(
          circleRadius: 9,
          circleColor: _hex(AppColors.primary600),
          circleStrokeWidth: 3,
          circleStrokeColor: _hex(AppColors.neutral0),
        ),
        enableInteraction: false,
      );
      if (mounted) {
        await controller.moveCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(widget.latitude, widget.longitude),
            AdminVisitMapCard.zoom,
          ),
        );
      }
    } catch (e) {
      debugPrint('AdminVisitMapCard error: $e');
    }
  }

  static String _hex(Color colour) =>
      '#${(colour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    if (!_hasValidCoordinates) {
      return Container(
        key: const Key('visit-map-card-empty'),
        height: AdminVisitMapCard.height,
        decoration: const BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: AppRadius.lgAll,
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.location_off_outlined,
                color: AppColors.neutral400,
                size: 36,
              ),
              SizedBox(height: AppSpacing.x2),
              Text(
                'Coordinates unavailable',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: AppRadius.lgAll,
      child: SizedBox(
        key: const Key('visit-map-card'),
        height: AdminVisitMapCard.height,
        child: IndiaMap(
          restrictBounds: false,
          onMapCreated: (controller) => _controller = controller,
          onStyleLoaded: () => unawaited(_onStyleLoaded()),
        ),
      ),
    );
  }
}
