import 'dart:math' as math;

import 'track_fix.dart';

/// Decides which GPS fixes are worth keeping.
///
/// The phone asks for a fix every 30 seconds. Keeping all of them wastes
/// data and battery when the employee is sitting at a dealer, but keeping too
/// few makes the route look like the phone was off: the server treats a
/// 15-minute hole as a gap. So a fix is kept when the phone has moved at
/// least [minDistanceM] (and further than the fix's own error), or when
/// [maxSilence] has passed since the last kept fix, even standing still.
class PointFilter {
  PointFilter({
    this.minDistanceM = 20,
    this.maxSilence = const Duration(minutes: 3),
    this.maxAccuracyM = 150,
  });

  final double minDistanceM;
  final Duration maxSilence;

  /// Fixes worse than this are dropped (indoor cell-tower guesses).
  final double maxAccuracyM;

  TrackFix? _last;

  /// The last kept fix.
  TrackFix? get last => _last;

  /// Forget the last kept fix (a new duty day).
  void reset() => _last = null;

  /// Whether to keep [fix]. Kept fixes become the new reference.
  bool accept(TrackFix fix) {
    if (!fix.accuracyM.isFinite || fix.accuracyM > maxAccuracyM) return false;
    final TrackFix? last = _last;
    if (last != null) {
      if (!fix.time.isAfter(last.time)) return false;
      final bool silentTooLong = fix.time.difference(last.time) >= maxSilence;
      final double moved = distanceM(
        last.latitude,
        last.longitude,
        fix.latitude,
        fix.longitude,
      );
      final double needed = math.max(minDistanceM, math.min(fix.accuracyM, 50));
      if (!silentTooLong && moved < needed) return false;
    }
    _last = fix;
    return true;
  }

  /// Great-circle distance in metres (haversine), the same formula the
  /// database uses.
  static double distanceM(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadiusM = 6371008.8;
    double rad(double deg) => deg * math.pi / 180;
    final double dLat = rad(lat2 - lat1);
    final double dLng = rad(lng2 - lng1);
    final double a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusM * math.asin(math.min(1, math.sqrt(a)));
  }
}
