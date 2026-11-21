import 'package:geolocator/geolocator.dart';

import '../../routes/domain/geo_point.dart';

/// A location for a camera photo.
class LocationFix {
  const LocationFix(this.point, {this.mocked = false});

  final GeoPoint point;

  /// Android says it came from a fake-location ("mock location") app.
  final bool mocked;
}

/// Where the phone is now, for a camera photo. Null if it cannot be found.
abstract interface class CurrentLocation {
  Future<LocationFix?> find();
}

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
      return LocationFix(GeoPoint(p.latitude, p.longitude), mocked: p.isMocked);
    } on Object {
      // Timed out indoors: a fix from the last 5 minutes is close enough.
      try {
        final Position? last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().difference(last.timestamp) <
                const Duration(minutes: 5)) {
          return LocationFix(
            GeoPoint(last.latitude, last.longitude),
            mocked: last.isMocked,
          );
        }
      } on Object {
        // No location at all.
      }
      return null;
    }
  }
}
