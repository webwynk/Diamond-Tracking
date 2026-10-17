import '../../domain/entities/location_point.dart';
import 'geo_math.dart';

/// On-device estimate of a session's distance, shown while the employee is on
/// duty (PRD F5).
///
/// It applies the same rules as the server's `private.session_distance_km`
/// (BR-8, BR-10): haversine between consecutive points, ignoring mock points,
/// points with accuracy worse than 100 m, and jumps faster than 55 m/s. The
/// server's figure, computed when duty ends, is the authoritative one; this
/// number exists so the screen is not blank in the meantime.
class SessionDistanceEstimator {
  static const double _maxAccuracyMeters = 100.0;
  static const double _maxSpeedMetersPerSecond = 55.0;

  LocationPoint? _previous;
  double _totalKm = 0.0;

  /// Distance accumulated so far, in kilometres.
  double get totalKm => _totalKm;

  /// Feeds the next point (in recorded order) and returns the running total.
  double add(LocationPoint point) {
    if (point.isMock || point.accuracy > _maxAccuracyMeters) return _totalKm;

    final previous = _previous;
    _previous = point;
    if (previous == null) return _totalKm;

    final seconds =
        point.recordedAt.difference(previous.recordedAt).inMilliseconds /
        1000.0;
    if (seconds <= 0) return _totalKm;

    final km = GeoMath.distanceKm(
      previous.latitude,
      previous.longitude,
      point.latitude,
      point.longitude,
    );
    if (km * 1000.0 / seconds > _maxSpeedMetersPerSecond) return _totalKm;

    _totalKm += km;
    return _totalKm;
  }
}
