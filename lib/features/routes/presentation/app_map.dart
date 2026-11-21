import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_text.dart';
import '../application/route_providers.dart';
import '../domain/geo_point.dart';
import 'map_pin_icons.dart';

/// What a pin on the map stands for (decides its look).
enum PinKind { start, end, stop, visit, person, personStale }

class MapPin {
  const MapPin({
    required this.id,
    required this.point,
    required this.kind,
    required this.title,
    this.label = '',
    this.snippet,
    this.onTap,
  });

  final String id;
  final GeoPoint point;
  final PinKind kind;
  final String title;

  /// Drawn on the pin: the stop's number.
  final String label;
  final String? snippet;
  final VoidCallback? onTap;
}

/// The Google map with route lines and pins, zoomed to fit them.
///
/// Each line is a stretch with signal; between two lines (no points came
/// in) a dotted line joins them. Only the native map is drawn here (free
/// with the Maps SDK for Android); no paid web services are called. In
/// widget tests it is a plain box.
///
/// Give it a `GlobalKey<AppMapState>` to zoom or move it from outside.
class AppMap extends ConsumerStatefulWidget {
  const AppMap({
    required this.lines,
    required this.pins,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<List<GeoPoint>> lines;
  final List<MapPin> pins;

  /// Space covered by things floating over the map (a top bar, a bottom
  /// card): fitting and the Google logo keep clear of it.
  final EdgeInsets padding;

  @override
  ConsumerState<AppMap> createState() => AppMapState();
}

class AppMapState extends ConsumerState<AppMap> {
  GoogleMapController? _controller;
  final Map<String, BitmapDescriptor> _icons = <String, BitmapDescriptor>{};

  /// Somewhere sensible before there is data: West Bengal.
  static const CameraPosition _initial = CameraPosition(
    target: LatLng(22.6, 88.4),
    zoom: 8,
  );

  List<GeoPoint> get _allPoints => <GeoPoint>[
    for (final List<GeoPoint> l in widget.lines) ...l,
    for (final MapPin p in widget.pins) p.point,
  ];

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  @override
  void didUpdateWidget(AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadIcons();
    if (oldWidget.lines.length != widget.lines.length ||
        oldWidget.pins.length != widget.pins.length) {
      _fit();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  static PinStyle _style(PinKind kind) => switch (kind) {
    PinKind.start => PinStyle.start,
    PinKind.end => PinStyle.end,
    PinKind.stop => PinStyle.stop,
    PinKind.visit => PinStyle.visit,
    PinKind.person => PinStyle.person,
    PinKind.personStale => PinStyle.personStale,
  };

  static String _iconKey(MapPin p) => '${p.kind.name}:${p.label}';

  /// Draws the pin pictures not drawn yet; the map shows Google's default
  /// pin for a moment until then.
  Future<void> _loadIcons() async {
    if (!ref.read(showGoogleMapProvider)) return;
    for (final MapPin p in widget.pins) {
      final String key = _iconKey(p);
      if (_icons.containsKey(key)) continue;
      final BitmapDescriptor icon = await MapPinIcons.icon(
        _style(p.kind),
        label: p.label,
      );
      if (!mounted) return;
      setState(() => _icons[key] = icon);
    }
  }

  /// Zooms in one step.
  Future<void> zoomIn() async =>
      _controller?.animateCamera(CameraUpdate.zoomIn());

  /// Zooms out one step.
  Future<void> zoomOut() async =>
      _controller?.animateCamera(CameraUpdate.zoomOut());

  /// Centres the map on [point], close enough to see the streets.
  Future<void> showPoint(GeoPoint point) async => _controller?.animateCamera(
    CameraUpdate.newLatLngZoom(LatLng(point.lat, point.lng), 16),
  );

  /// Zooms to show every line and pin.
  Future<void> fitAll() => _fit();

  Future<void> _fit() async {
    final GoogleMapController? c = _controller;
    final List<GeoPoint> points = _allPoints;
    if (c == null || points.isEmpty) return;
    if (points.length == 1) {
      await showPoint(points[0]);
      return;
    }
    double south = points[0].lat;
    double north = south;
    double west = points[0].lng;
    double east = west;
    for (final GeoPoint p in points) {
      south = math.min(south, p.lat);
      north = math.max(north, p.lat);
      west = math.min(west, p.lng);
      east = math.max(east, p.lng);
    }
    // A tiny box (all points in one place) would zoom in too far.
    const double pad = 0.002;
    await c.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south - pad, west - pad),
          northeast: LatLng(north + pad, east + pad),
        ),
        48,
      ),
    );
  }

  /// Dotted joins between the end of one stretch and the start of the next.
  List<List<GeoPoint>> get _gaps => <List<GeoPoint>>[
    for (int i = 1; i < widget.lines.length; i++)
      if (widget.lines[i - 1].isNotEmpty && widget.lines[i].isNotEmpty)
        <GeoPoint>[widget.lines[i - 1].last, widget.lines[i].first],
  ];

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(showGoogleMapProvider)) {
      return Container(
        color: DsColors.surface,
        alignment: Alignment.center,
        child: Text(
          'Map: ${widget.lines.length} lines, ${_gaps.length} gaps, '
          '${widget.pins.length} pins',
          style: DsText.caption,
        ),
      );
    }
    LatLng at(GeoPoint p) => LatLng(p.lat, p.lng);
    return GoogleMap(
      initialCameraPosition: _initial,
      padding: widget.padding,
      onMapCreated: (GoogleMapController c) {
        _controller = c;
        _fit();
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      polylines: <Polyline>{
        for (int i = 0; i < widget.lines.length; i++)
          Polyline(
            polylineId: PolylineId('line$i'),
            points: <LatLng>[for (final GeoPoint p in widget.lines[i]) at(p)],
            color: DsColors.primary,
            width: 6,
          ),
        for (final (int i, List<GeoPoint> gap) in _gaps.indexed)
          Polyline(
            polylineId: PolylineId('gap$i'),
            points: <LatLng>[at(gap[0]), at(gap[1])],
            color: DsColors.primary,
            width: 5,
            patterns: <PatternItem>[PatternItem.dot, PatternItem.gap(12)],
          ),
      },
      markers: <Marker>{
        for (final MapPin pin in widget.pins)
          Marker(
            markerId: MarkerId(pin.id),
            position: at(pin.point),
            icon: _icons[_iconKey(pin)] ?? BitmapDescriptor.defaultMarker,
            anchor: MapPinIcons.anchorOf(_style(pin.kind)),
            zIndexInt: pin.kind == PinKind.person ? 2 : 1,
            infoWindow: InfoWindow(
              title: pin.title,
              snippet: pin.snippet,
              onTap: pin.onTap,
            ),
          ),
      },
    );
  }
}
