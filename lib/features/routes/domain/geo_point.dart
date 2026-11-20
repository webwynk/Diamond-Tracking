/// A position in degrees. Kept separate from the map package's LatLng so the
/// route logic is tested without the map.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// Decodes Google's encoded polyline format (precision 1e-5), which the
/// database writes for each route segment.
List<GeoPoint> decodePolyline(String encoded) {
  final List<GeoPoint> points = <GeoPoint>[];
  int index = 0;
  int lat = 0;
  int lng = 0;
  int next() {
    int result = 0;
    int shift = 0;
    int b;
    do {
      if (index >= encoded.length) throw const FormatException('cut short');
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    lat += next();
    lng += next();
    points.add(GeoPoint(lat / 1e5, lng / 1e5));
  }
  return points;
}
