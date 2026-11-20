import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../application/route_providers.dart';
import '../domain/geo_point.dart';

/// What a pin on the map stands for (decides its colour).
enum PinKind { start, end, stop, person, personStale }

class MapPin {
  const MapPin({
    required this.id,
    required this.point,
    required this.kind,
    required this.title,
    this.snippet,
    this.onTap,
  });

  final String id;
  final GeoPoint point;
  final PinKind kind;
  final String title;
  final String? snippet;
  final VoidCallback? onTap;
}

/// The Google map with route lines and pins, zoomed to fit them.
///
/// Only the native map is drawn here (free with the Maps SDK for Android);
/// no paid web services are called. In widget tests it is a plain box.
class AppMap extends ConsumerStatefulWidget {
  const AppMap({required this.lines, required this.pins, super.key});

  final List<List<GeoPoint>> lines;
  final List<MapPin> pins;

  @override
  ConsumerState<AppMap> createState() => _AppMapState();
}

class _AppMapState extends ConsumerState<AppMap> {
  GoogleMapController? _controller;

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
  void didUpdateWidget(AppMap old) {
    super.didUpdateWidget(old);
    if (old.lines.length != widget.lines.length ||
        old.pins.length != widget.pins.length) {
      _fit();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _fit() async {
    final GoogleMapController? c = _controller;
    final List<GeoPoint> points = _allPoints;
    if (c == null || points.isEmpty) return;
    if (points.length == 1) {
      await c.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(points[0].lat, points[0].lng), 15),
      );
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

  static double _hue(PinKind kind) => switch (kind) {
    PinKind.start => BitmapDescriptor.hueGreen,
    PinKind.end => BitmapDescriptor.hueRed,
    PinKind.stop => BitmapDescriptor.hueOrange,
    PinKind.person => BitmapDescriptor.hueAzure,
    PinKind.personStale => BitmapDescriptor.hueYellow,
  };

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(showGoogleMapProvider)) {
      return Container(
        color: AppColors.neutral100,
        alignment: Alignment.center,
        child: Text(
          'Map: ${widget.lines.length} lines, ${widget.pins.length} pins',
          style: AppTypography.caption,
        ),
      );
    }
    return GoogleMap(
      initialCameraPosition: _initial,
      onMapCreated: (GoogleMapController c) {
        _controller = c;
        _fit();
      },
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      polylines: <Polyline>{
        for (int i = 0; i < widget.lines.length; i++)
          Polyline(
            polylineId: PolylineId('line$i'),
            points: <LatLng>[
              for (final GeoPoint p in widget.lines[i]) LatLng(p.lat, p.lng),
            ],
            color: AppColors.primary600,
            width: 5,
          ),
      },
      markers: <Marker>{
        for (final MapPin pin in widget.pins)
          Marker(
            markerId: MarkerId(pin.id),
            position: LatLng(pin.point.lat, pin.point.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(_hue(pin.kind)),
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
