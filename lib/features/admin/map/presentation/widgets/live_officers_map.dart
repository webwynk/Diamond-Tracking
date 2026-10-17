import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../domain/entities/live_position.dart';
import '../../../../../shared/widgets/india_map.dart';
import '../controllers/admin_live_map_state.dart';

/// The admin live map: one dot per on-duty employee, grouped into clusters
/// when they are close together.
///
/// Built the way docs/07 section 3 requires: ONE clustered GeoJSON source and
/// style layers, never a Flutter widget per employee. New positions replace the
/// source's data in place; the layers are never recreated and the camera never
/// moves because data arrived.
///
/// Circle layers carry the whole meaning (colour for status, size for how
/// worrying it is, a ring for the selected person). Text labels are drawn as an
/// extra on top: the spike found text layers do not render on the software-GL
/// emulator, so nothing essential depends on them.
class LiveOfficersMap extends StatefulWidget {
  const LiveOfficersMap({
    super.key,
    required this.officers,
    required this.selectedId,
    required this.onOfficerTapped,
  });

  /// Who to draw (already filtered).
  final List<LiveOfficer> officers;

  /// The employee with an open card; drawn with a ring.
  final String? selectedId;

  /// Called with the employee id when a single dot is tapped.
  final ValueChanged<String> onOfficerTapped;

  @override
  State<LiveOfficersMap> createState() => LiveOfficersMapState();
}

class LiveOfficersMapState extends State<LiveOfficersMap> {
  static const String _sourceId = 'officers';
  static const String _clusterLayer = 'officer-clusters';
  static const String _clusterCountLayer = 'officer-cluster-count';
  static const String _pointLayer = 'officer-points';
  static const String _labelLayer = 'officer-labels';
  static const String _selectedLayer = 'officer-selected';

  /// OpenFreeMap serves glyphs for these names only (docs/07 section 0).
  static const List<String> _fonts = <String>['Noto Sans Bold'];

  MapLibreMapController? _controller;

  /// A zoom asked for before the native map existed; done once it does.
  LivePosition? _pendingFly;
  bool _ready = false;
  bool _pushing = false;
  bool _pushAgain = false;

  @override
  void didUpdateWidget(LiveOfficersMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameDrawing(oldWidget.officers, widget.officers)) unawaited(_push());
    if (oldWidget.selectedId != widget.selectedId) unawaited(_markSelected());
  }

  @override
  void dispose() {
    _controller?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
  }

  /// Moves the camera to show everyone drawn, on the admin's request.
  Future<void> fitToOfficers() async {
    final controller = _controller;
    final officers = widget.officers;
    if (controller == null) return;
    if (officers.isEmpty) {
      await IndiaMap.recenter(controller);
      return;
    }
    if (officers.length == 1) {
      final only = officers.first.position;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(only.latitude, only.longitude), 15),
      );
      return;
    }
    var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
    for (final officer in officers) {
      final p = officer.position;
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
        left: 56,
        top: 180,
        right: 56,
        bottom: 150,
      ),
    );
  }

  /// Moves the camera to one employee, on the admin's request.
  Future<void> flyTo(LivePosition position) async {
    final controller = _controller;
    if (controller == null) {
      _pendingFly = position;
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        16,
      ),
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onFeatureTapped.add(_onFeatureTapped);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    _ready = false;
    try {
      await controller.addSource(
        _sourceId,
        GeojsonSourceProperties(
          data: _geoJson(),
          cluster: true,
          clusterRadius: 50,
          // Above this zoom every employee is drawn on their own.
          clusterMaxZoom: 12,
          // A cluster carries the worst severity inside it, so a red employee
          // is never hidden in a green cluster.
          clusterProperties: const <String, Object>{
            'maxSeverity': <Object>[
              'max',
              <Object>['get', 'severity'],
            ],
          },
        ),
      );
      await controller.addCircleLayer(
        _sourceId,
        _clusterLayer,
        CircleLayerProperties(
          circleColor: _severityColour('maxSeverity'),
          circleRadius: const <Object>[
            'step',
            <Object>['get', 'point_count'],
            18,
            10,
            22,
            50,
            28,
          ],
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
        filter: const <Object>['has', 'point_count'],
      );
      await controller.addCircleLayer(
        _sourceId,
        _pointLayer,
        CircleLayerProperties(
          circleColor: _severityColour('severity'),
          // Bigger for the ones that need attention: size, not colour alone.
          circleRadius: const <Object>[
            'match',
            <Object>['get', 'severity'],
            3,
            12,
            2,
            10,
            8,
          ],
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
        filter: const <Object>[
          '!',
          <Object>['has', 'point_count'],
        ],
      );
      await controller.addCircleLayer(
        _sourceId,
        _selectedLayer,
        CircleLayerProperties(
          circleColor: '#FFFFFF',
          circleOpacity: 0,
          circleRadius: 17,
          circleStrokeColor: _hex(AppColors.primary600),
          circleStrokeWidth: 3,
        ),
        filter: _selectedFilter(widget.selectedId),
        enableInteraction: false,
      );
      _ready = true;
      final pending = _pendingFly;
      _pendingFly = null;
      if (pending != null) unawaited(flyTo(pending));
      await _addTextLayers(controller);
    } on Object catch (e, st) {
      debugPrint('LiveOfficersMap: could not set up the layers: $e\n$st');
    }
  }

  /// Counts and names. Optional: a failure here must leave the dots working.
  Future<void> _addTextLayers(MapLibreMapController controller) async {
    try {
      await controller.addSymbolLayer(
        _sourceId,
        _clusterCountLayer,
        const SymbolLayerProperties(
          textField: <Object>['get', 'point_count_abbreviated'],
          textFont: _fonts,
          textSize: 14,
          textColor: '#FFFFFF',
          textAllowOverlap: true,
        ),
        filter: const <Object>['has', 'point_count'],
        enableInteraction: false,
      );
      await controller.addSymbolLayer(
        _sourceId,
        _labelLayer,
        const SymbolLayerProperties(
          textField: <Object>['get', 'name'],
          textFont: _fonts,
          textSize: 12,
          textColor: '#0F172A',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.6,
          textAnchor: 'top',
          textOffset: <Object>[0, 1.2],
          textOptional: true,
        ),
        minzoom: 9,
        filter: const <Object>[
          '!',
          <Object>['has', 'point_count'],
        ],
        enableInteraction: false,
      );
    } on Object catch (e) {
      debugPrint('LiveOfficersMap: text layers unavailable: $e');
    }
  }

  Future<void> _push() async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    // One update in flight at a time; if more arrive meanwhile, send the
    // newest once.
    if (_pushing) {
      _pushAgain = true;
      return;
    }
    _pushing = true;
    try {
      await controller.setGeoJsonSource(_sourceId, _geoJson());
    } on Object catch (e) {
      debugPrint('LiveOfficersMap: could not update the positions: $e');
    } finally {
      _pushing = false;
    }
    if (_pushAgain && mounted) {
      _pushAgain = false;
      await _push();
    }
  }

  Future<void> _markSelected() async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    try {
      await controller.setFilter(
        _selectedLayer,
        _selectedFilter(widget.selectedId),
      );
    } on Object catch (e) {
      debugPrint('LiveOfficersMap: could not mark the selection: $e');
    }
  }

  Future<void> _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    try {
      final hits = await controller.queryRenderedFeatures(point, const <String>[
        _clusterLayer,
        _pointLayer,
      ], null);
      if (hits.isEmpty || !mounted) return;
      final feature = hits.first;
      final properties = feature is Map ? feature['properties'] : null;
      if (properties is! Map) return;

      final clusterId = properties['cluster_id'];
      if (clusterId is num) {
        // A cluster: zoom to where it splits.
        final zoom = await controller.getClusterExpansionZoom(
          _sourceId,
          clusterId.toInt(),
        );
        if (!mounted) return;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(coordinates, zoom + 0.5),
        );
        return;
      }
      final employeeId = properties['id'];
      if (employeeId is String) widget.onOfficerTapped(employeeId);
    } on Object catch (e) {
      debugPrint('LiveOfficersMap: could not read the tap: $e');
    }
  }

  Map<String, dynamic> _geoJson() {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        for (final officer in widget.officers)
          <String, dynamic>{
            'type': 'Feature',
            'id': officer.id,
            'properties': <String, dynamic>{
              'id': officer.id,
              'name': officer.name,
              'severity': severityOf(officer.status),
            },
            'geometry': <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[
                officer.position.longitude,
                officer.position.latitude,
              ],
            },
          },
      ],
    };
  }

  /// Whether two lists would draw exactly the same map, so an unrelated
  /// rebuild does not resend 150 positions.
  static bool _sameDrawing(List<LiveOfficer> a, List<LiveOfficer> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].name != b[i].name ||
          a[i].status != b[i].status ||
          !identical(a[i].position, b[i].position)) {
        return false;
      }
    }
    return true;
  }

  /// 1 = on duty, 2 = stale, 3 = needs checking (a higher number is worse).
  @visibleForTesting
  static int severityOf(LiveStatus status) => switch (status) {
    LiveStatus.active => 1,
    LiveStatus.stale => 2,
    LiveStatus.suspect => 3,
  };

  static Object _severityColour(String property) => <Object>[
    'match',
    <Object>['get', property],
    3,
    _hex(AppColors.statusSuspect),
    2,
    _hex(AppColors.statusStale),
    _hex(AppColors.statusActive),
  ];

  static List<Object> _selectedFilter(String? selectedId) => <Object>[
    '==',
    <Object>['get', 'id'],
    selectedId ?? '',
  ];

  static String _hex(Color colour) =>
      '#${(colour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    return IndiaMap(onMapCreated: _onMapCreated, onStyleLoaded: _onStyleLoaded);
  }
}
