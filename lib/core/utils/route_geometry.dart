import 'dart:math';

import '../../domain/entities/route_day.dart';

/// What a day's stored points turn into for drawing.
class RouteAnalysis {
  const RouteAnalysis({
    required this.lines,
    required this.mockPoints,
    required this.inaccuratePoints,
    required this.jumpCount,
    required this.goodPointCount,
    required this.first,
    required this.last,
  });

  /// The route as drawn: simplified, in pieces. A new piece starts at each new
  /// session and after each impossible jump, so a jump never looks like travel.
  /// Every piece has at least two points.
  final List<List<RoutePoint>> lines;

  /// Points the phone flagged as mock locations. Drawn on their own, red, and
  /// left out of the line.
  final List<RoutePoint> mockPoints;

  /// Points whose reported accuracy is worse than 100 m. Drawn on their own,
  /// amber, and left out of the line.
  final List<RoutePoint> inaccuratePoints;

  /// Moves faster than 55 m/s (198 km/h) between two good points: the line is
  /// broken there. The same rule the server uses for distance.
  final int jumpCount;

  /// Points that count (not mock, accurate enough). Not the drawn count.
  final int goodPointCount;

  /// First and last good point, or null when there is none.
  final RoutePoint? first;
  final RoutePoint? last;

  int get flaggedCount => mockPoints.length + inaccuratePoints.length;

  bool get hasAnythingToDraw =>
      first != null || mockPoints.isNotEmpty || inaccuratePoints.isNotEmpty;

  /// Every point worth showing in view, for fitting the camera.
  Iterable<RoutePoint> get framePoints sync* {
    for (final line in lines) {
      yield* line;
    }
    final firstPoint = first;
    final lastPoint = last;
    if (firstPoint != null) yield firstPoint;
    if (lastPoint != null) yield lastPoint;
    yield* mockPoints;
    yield* inaccuratePoints;
  }
}

/// Route geometry for the admin route view.
///
/// Display only. Distance is NEVER taken from the simplified line: the totals
/// come from the server, from the full point set (docs/07 section 4). The
/// rules here mirror `private.session_distance_km` so the picture and the
/// server's kilometres agree about which points count.
abstract final class RouteGeometry {
  const RouteGeometry._();

  /// Worse than this and a point is not trusted (server rule).
  static const double maxAccuracyMeters = 100;

  /// Faster than this between two good points is an impossible jump (server
  /// rule: 55 m/s).
  static const double maxSpeedMetersPerSecond = 55;

  /// Simplification tolerance for drawing, in metres.
  static const double toleranceMeters = 10;

  /// A day too big for the finer tolerance is simplified harder, so the map
  /// never stalls.
  static const int hugeDayPoints = 10000;
  static const double hugeDayToleranceMeters = 25;

  static const double _earthRadiusMeters = 6371008.8;

  /// Great-circle distance between two points, in metres.
  static double distanceMeters(RoutePoint a, RoutePoint b) {
    final dLat = _radians(b.latitude - a.latitude);
    final dLon = _radians(b.longitude - a.longitude);
    final h =
        pow(sin(dLat / 2), 2) +
        cos(_radians(a.latitude)) *
            cos(_radians(b.latitude)) *
            pow(sin(dLon / 2), 2);
    return 2 * _earthRadiusMeters * asin(sqrt(min(1.0, h.toDouble())));
  }

  /// Sorts a day's points into the line, the flagged points and the counts.
  /// [points] must already be in time order (the repository reads them so).
  static RouteAnalysis analyse(List<RoutePoint> points) {
    final tolerance = points.length > hugeDayPoints
        ? hugeDayToleranceMeters
        : toleranceMeters;

    final mock = <RoutePoint>[];
    final inaccurate = <RoutePoint>[];
    final pieces = <List<RoutePoint>>[];
    var jumps = 0;
    var good = 0;
    RoutePoint? first;
    RoutePoint? last;

    // One session at a time, so the line never joins two sessions.
    final bySession = <String, List<RoutePoint>>{};
    for (final point in points) {
      bySession.putIfAbsent(point.sessionId, () => <RoutePoint>[]).add(point);
    }

    for (final session in bySession.values) {
      var piece = <RoutePoint>[];
      void close() {
        if (piece.length >= 2) pieces.add(piece);
        piece = <RoutePoint>[];
      }

      for (final point in session) {
        if (point.isMock) {
          mock.add(point);
          continue;
        }
        final accuracy = point.accuracy;
        if (accuracy != null && accuracy > maxAccuracyMeters) {
          inaccurate.add(point);
          continue;
        }
        good++;
        first ??= point;
        last = point;

        if (piece.isNotEmpty) {
          final seconds =
              point.recordedAt
                  .difference(piece.last.recordedAt)
                  .inMilliseconds /
              1000.0;
          final speed = seconds > 0
              ? distanceMeters(piece.last, point) / seconds
              : 0.0;
          if (speed > maxSpeedMetersPerSecond) {
            jumps++;
            close();
          }
        }
        piece.add(point);
      }
      close();
    }

    return RouteAnalysis(
      lines: [for (final piece in pieces) simplify(piece, tolerance)],
      mockPoints: mock,
      inaccuratePoints: inaccurate,
      jumpCount: jumps,
      goodPointCount: good,
      first: first,
      last: last,
    );
  }

  /// Douglas-Peucker simplification, for drawing only. Keeps the first and the
  /// last point, and every point further than [toleranceMeters] from the line
  /// between its neighbours. Iterative, so a long day cannot overflow the stack.
  static List<RoutePoint> simplify(
    List<RoutePoint> points,
    double toleranceMeters,
  ) {
    if (points.length < 3) return List<RoutePoint>.of(points);

    // Flat local metres around the middle of the piece: exact enough for
    // simplification, and much cheaper than great-circle maths per point.
    final lat0 = points.first.latitude;
    final lon0 = points.first.longitude;
    final xScale = 111320.0 * cos(_radians(lat0));
    const yScale = 110574.0;
    final xs = List<double>.generate(
      points.length,
      (i) => (points[i].longitude - lon0) * xScale,
    );
    final ys = List<double>.generate(
      points.length,
      (i) => (points[i].latitude - lat0) * yScale,
    );

    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;

    final stack = <(int, int)>[(0, points.length - 1)];
    while (stack.isNotEmpty) {
      final (start, end) = stack.removeLast();
      if (end - start < 2) continue;

      var farthest = -1;
      var farthestDistance = toleranceMeters;
      for (var i = start + 1; i < end; i++) {
        final d = _distanceToSegment(
          xs[i],
          ys[i],
          xs[start],
          ys[start],
          xs[end],
          ys[end],
        );
        if (d > farthestDistance) {
          farthest = i;
          farthestDistance = d;
        }
      }
      if (farthest != -1) {
        keep[farthest] = true;
        stack
          ..add((start, farthest))
          ..add((farthest, end));
      }
    }

    return [
      for (var i = 0; i < points.length; i++)
        if (keep[i]) points[i],
    ];
  }

  static double _distanceToSegment(
    double px,
    double py,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return sqrt(pow(px - ax, 2) + pow(py - ay, 2));
    final t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(
      0.0,
      1.0,
    );
    final cx = ax + t * dx;
    final cy = ay + t * dy;
    return sqrt(pow(px - cx, 2) + pow(py - cy, 2));
  }

  static double _radians(double degrees) => degrees * pi / 180.0;
}
