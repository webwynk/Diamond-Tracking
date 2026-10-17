import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/route_geometry.dart';
import '../../../../../domain/entities/route_day.dart';
import '../../../../../shared/widgets/india_map.dart';

/// The route of one day, drawn on the real map as a static picture (docs/07
/// section 4): one highlighted line, a start and an end (or current position),
/// and the flagged points on their own. No playback, no animation.
///
/// Built as two GeoJSON sources and style layers. The line and the points are
/// replaced in place when the day changes; the camera fits the whole route when
/// a day loads and on the admin's request, never otherwise. Circles and a line
/// carry all the meaning; no text layer is needed.
class AdminRouteMapView extends StatefulWidget {
  const AdminRouteMapView({
    super.key,
    required this.analysis,
    required this.showCurrent,
  });

  /// What to draw, or null for nothing (loading, no duty, expired).
  final RouteAnalysis? analysis;

  /// The last point is where the employee is now (today, still on duty), so it
  /// is drawn as the current position instead of an end.
  final bool showCurrent;

  @override
  State<AdminRouteMapView> createState() => AdminRouteMapViewState();
}

class AdminRouteMapViewState extends State<AdminRouteMapView> {
  static const String _lineSource = 'route-line';
  static const String _markSource = 'route-marks';
  static const String _casingLayer = 'route-casing';
  static const String _lineLayer = 'route-line-layer';
  static const String _flaggedLayer = 'route-flagged';
  static const String _endpointsLayer = 'route-endpoints';

  MapLibreMapController? _controller;
  bool _ready = false;

  @override
  void didUpdateWidget(AdminRouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.analysis, widget.analysis) ||
        oldWidget.showCurrent != widget.showCurrent) {
      unawaited(_push(fit: true));
    }
  }

  /// Moves the camera to show the whole route, on load and on request.
  Future<void> fit() async {
    final controller = _controller;
    final analysis = widget.analysis;
    if (controller == null || analysis == null) return;
    final points = analysis.framePoints.toList();
    if (points.isEmpty) return;
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(points.first.latitude, points.first.longitude),
          15,
        ),
      );
      return;
    }
    var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
    for (final p in points) {
      south = min(south, p.latitude);
      north = max(north, p.latitude);
      west = min(west, p.longitude);
      east = max(east, p.longitude);
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        left: 48,
        top: 88,
        right: 48,
        bottom: 48,
      ),
    );
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    _ready = false;
    try {
      await controller.addSource(
        _lineSource,
        GeojsonSourceProperties(data: _lineGeoJson()),
      );
      await controller.addSource(
        _markSource,
        GeojsonSourceProperties(data: _markGeoJson()),
      );
      // A white casing under the line keeps it readable on any base map.
      await controller.addLineLayer(
        _lineSource,
        _casingLayer,
        const LineLayerProperties(
          lineColor: '#FFFFFF',
          lineWidth: 8,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      await controller.addLineLayer(
        _lineSource,
        _lineLayer,
        LineLayerProperties(
          lineColor: _hex(AppColors.primary600),
          lineWidth: 4,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      await controller.addCircleLayer(
        _markSource,
        _flaggedLayer,
        CircleLayerProperties(
          circleColor: <Object>[
            'match',
            <Object>['get', 'kind'],
            'mock',
            _hex(AppColors.statusSuspect),
            _hex(AppColors.statusStale),
          ],
          circleRadius: 6,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
        filter: const <Object>[
          'in',
          <Object>['get', 'kind'],
          <Object>[
            'literal',
            <String>['mock', 'inaccurate'],
          ],
        ],
        enableInteraction: false,
      );
      await controller.addCircleLayer(
        _markSource,
        _endpointsLayer,
        CircleLayerProperties(
          circleColor: <Object>[
            'match',
            <Object>['get', 'kind'],
            'start',
            _hex(AppColors.statusActive),
            'current',
            _hex(AppColors.primary600),
            _hex(AppColors.statusBlocked),
          ],
          circleRadius: 10,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
        filter: const <Object>[
          'in',
          <Object>['get', 'kind'],
          <Object>[
            'literal',
            <String>['start', 'end', 'current'],
          ],
        ],
        enableInteraction: false,
      );
      _ready = true;
      unawaited(fit());
    } on Object catch (e, st) {
      debugPrint('AdminRouteMapView: could not set up the layers: $e\n$st');
    }
  }

  Future<void> _push({required bool fit}) async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    try {
      await controller.setGeoJsonSource(_lineSource, _lineGeoJson());
      await controller.setGeoJsonSource(_markSource, _markGeoJson());
      if (fit && mounted) await this.fit();
    } on Object catch (e) {
      debugPrint('AdminRouteMapView: could not update the route: $e');
    }
  }

  Map<String, dynamic> _lineGeoJson() {
    final analysis = widget.analysis;
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        if (analysis != null)
          for (final line in analysis.lines)
            <String, dynamic>{
              'type': 'Feature',
              'properties': <String, dynamic>{},
              'geometry': <String, dynamic>{
                'type': 'LineString',
                'coordinates': <List<double>>[
                  for (final p in line) <double>[p.longitude, p.latitude],
                ],
              },
            },
      ],
    };
  }

  Map<String, dynamic> _markGeoJson() {
    final analysis = widget.analysis;
    final marks = <(RoutePoint, String)>[];
    if (analysis != null) {
      final first = analysis.first;
      final last = analysis.last;
      if (first != null) marks.add((first, 'start'));
      if (last != null && !identical(last, first)) {
        marks.add((last, widget.showCurrent ? 'current' : 'end'));
      }
      for (final p in analysis.inaccuratePoints) {
        marks.add((p, 'inaccurate'));
      }
      for (final p in analysis.mockPoints) {
        marks.add((p, 'mock'));
      }
    }
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        for (final (point, kind) in marks)
          <String, dynamic>{
            'type': 'Feature',
            'properties': <String, dynamic>{'kind': kind},
            'geometry': <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[point.longitude, point.latitude],
            },
          },
      ],
    };
  }

  static String _hex(Color colour) =>
      '#${(colour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    return IndiaMap(
      onMapCreated: (controller) => _controller = controller,
      onStyleLoaded: _onStyleLoaded,
    );
  }
}
