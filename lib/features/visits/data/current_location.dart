import 'package:geolocator/geolocator.dart';

import '../../routes/domain/geo_point.dart';

/// A location for a camera photo.
class LocationFix {
  const LocationFix(this.point, {this.mocked = false, this.accuracyM});

  final GeoPoint point;

  /// How far off it may be, in metres (L59).
  final int? accuracyM;

  /// Android says it came from a fake-location ("mock location") app.
  final bool mocked;
}

/// Where the phone is now, for a camera photo. Null if it cannot be found.
abstract interface class CurrentLocation {
  Future<LocationFix?> find();
}

/// The oldest last-known location a camera photo may use when no new one
/// comes in time (L59). Older ones can be far away after driving.
const Duration lastKnownMaxAge = Duration(minutes: 2);

/// Whether a last-known location taken at [fixAt] is fresh enough at [now].
bool lastKnownIsFresh(DateTime fixAt, DateTime now) =>
    now.difference(fixAt) < lastKnownMaxAge;

int? _accuracy(Position p) =>
    p.accuracy.isFinite && p.accuracy > 0 ? p.accuracy.round() : null;

class GeolocatorLocation implements CurrentLocation {
  const GeolocatorLocation();

  @override
  Future<LocationFix?> find() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final Position p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationFix(
        GeoPoint(p.latitude, p.longitude),
        mocked: p.isMocked,
        accuracyM: _accuracy(p),
      );
    } on Object {
      // Timed out indoors: a fix from the last 2 minutes is close enough.
      try {
        final Position? last = await Geolocator.getLastKnownPosition();
        if (last != null && lastKnownIsFresh(last.timestamp, DateTime.now())) {
          return LocationFix(
            GeoPoint(last.latitude, last.longitude),
            mocked: last.isMocked,
            accuracyM: _accuracy(last),
          );
        }
      } on Object {
        // No location at all.
      }
      return null;
    }
  }
}
