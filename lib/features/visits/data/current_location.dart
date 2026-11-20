import 'package:geolocator/geolocator.dart';

import '../../routes/domain/geo_point.dart';

/// Where the phone is now, for a camera photo. Null if it cannot be found.
abstract interface class CurrentLocation {
  Future<GeoPoint?> find();
}

class GeolocatorLocation implements CurrentLocation {
  const GeolocatorLocation();

  @override
  Future<GeoPoint?> find() async {
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
      return GeoPoint(p.latitude, p.longitude);
    } on Object {
      // Timed out indoors: a fix from the last 5 minutes is close enough.
      try {
        final Position? last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().difference(last.timestamp) <
                const Duration(minutes: 5)) {
          return GeoPoint(last.latitude, last.longitude);
        }
      } on Object {
        // No location at all.
      }
      return null;
    }
  }
}
