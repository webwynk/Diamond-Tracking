import 'dart:math';

/// Great-circle distance between two WGS84 points, the same formula the
/// server uses to total a session (BR-8), so the phone's estimate and the
/// server's figure agree.
abstract final class GeoMath {
  const GeoMath._();

  static const double earthRadiusKm = 6371.0088;

  static double distanceKm(
    double fromLat,
    double fromLon,
    double toLat,
    double toLon,
  ) {
    final dLat = _radians(toLat - fromLat);
    final dLon = _radians(toLon - fromLon);
    final h =
        pow(sin(dLat / 2), 2) +
        cos(_radians(fromLat)) * cos(_radians(toLat)) * pow(sin(dLon / 2), 2);
    return earthRadiusKm * 2 * asin(sqrt(min(1.0, h.toDouble())));
  }

  static double distanceMeters(
    double fromLat,
    double fromLon,
    double toLat,
    double toLon,
  ) => distanceKm(fromLat, fromLon, toLat, toLon) * 1000.0;

  static double _radians(double degrees) => degrees * pi / 180.0;
}
