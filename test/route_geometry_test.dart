import 'package:diamond_tracking/core/utils/route_geometry.dart';
import 'package:diamond_tracking/domain/entities/route_day.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _base = DateTime.utc(2026, 10, 17, 3);

RoutePoint _p(
  double lat,
  double lon,
  int seconds, {
  String session = 's1',
  double? accuracy = 5,
  bool isMock = false,
}) => RoutePoint(
  sessionId: session,
  latitude: lat,
  longitude: lon,
  recordedAt: _base.add(Duration(seconds: seconds)),
  accuracy: accuracy,
  isMock: isMock,
);

void main() {
  group('distanceMeters', () {
    test(
      'matches a known distance (0.001 degree of latitude is about 111 m)',
      () {
        final d = RouteGeometry.distanceMeters(
          _p(20.000, 73, 0),
          _p(20.001, 73, 1),
        );
        expect(d, closeTo(111.2, 0.5));
      },
    );

    test('is zero for the same place and symmetric', () {
      final a = _p(19.9, 73.8, 0);
      final b = _p(19.95, 73.85, 1);
      expect(RouteGeometry.distanceMeters(a, a), 0);
      expect(
        RouteGeometry.distanceMeters(a, b),
        closeTo(RouteGeometry.distanceMeters(b, a), 1e-6),
      );
    });
  });

  group('analyse: which points count (the server rule)', () {
    test('a normal day is one line from first to last', () {
      final analysis = RouteGeometry.analyse([
        _p(20.000, 73, 0),
        _p(20.001, 73, 10),
        _p(20.002, 73, 20),
      ]);

      expect(analysis.goodPointCount, 3);
      expect(analysis.first!.latitude, 20.000);
      expect(analysis.last!.latitude, 20.002);
      expect(analysis.lines, hasLength(1));
      expect(analysis.jumpCount, 0);
      expect(analysis.flaggedCount, 0);
      expect(analysis.hasAnythingToDraw, isTrue);
    });

    test('mock points are set aside and never join the line', () {
      final analysis = RouteGeometry.analyse([
        _p(20.000, 73, 0),
        _p(25.000, 80, 5, isMock: true),
        _p(20.001, 73, 10),
      ]);

      expect(analysis.mockPoints, hasLength(1));
      expect(analysis.goodPointCount, 2);
      expect(analysis.jumpCount, 0, reason: 'the fake point is not a jump');
      for (final line in analysis.lines) {
        expect(line.any((p) => p.latitude == 25.0), isFalse);
      }
    });

    test(
      'accuracy over 100 m is set aside; 100 m and "unknown" still count',
      () {
        final analysis = RouteGeometry.analyse([
          _p(20.0000, 73, 0, accuracy: 100),
          _p(20.0001, 73, 10, accuracy: null),
          _p(20.0002, 73, 20, accuracy: 100.1),
        ]);

        expect(analysis.inaccuratePoints, hasLength(1));
        expect(analysis.goodPointCount, 2);
      },
    );

    test('a move faster than 55 m/s breaks the line instead of joining it', () {
      // About 1.1 km in 10 s = 110 m/s.
      final analysis = RouteGeometry.analyse([
        _p(20.000, 73, 0),
        _p(20.0001, 73, 10),
        _p(20.010, 73, 20),
        _p(20.0101, 73, 30),
      ]);

      expect(analysis.jumpCount, 1);
      expect(analysis.lines, hasLength(2));
      expect(analysis.lines[0].last.latitude, 20.0001);
      expect(analysis.lines[1].first.latitude, 20.010);
      expect(analysis.goodPointCount, 4, reason: 'both ends of a jump count');
    });

    test('exactly at the limit is allowed; just over is a jump', () {
      // 0.0005 degree is about 55.6 m: over 55 m/s in 1 s, under it in 2 s.
      final slow = RouteGeometry.analyse([_p(20, 73, 0), _p(20.0005, 73, 2)]);
      final fast = RouteGeometry.analyse([_p(20, 73, 0), _p(20.0005, 73, 1)]);

      expect(slow.jumpCount, 0);
      expect(fast.jumpCount, 1);
    });

    test('two points at the same instant are not a jump', () {
      final analysis = RouteGeometry.analyse([
        _p(20.000, 73, 0),
        _p(20.0001, 73, 0),
      ]);

      expect(analysis.jumpCount, 0);
      expect(analysis.lines, hasLength(1));
    });

    test('two sessions are never joined, even when one follows the other', () {
      final analysis = RouteGeometry.analyse([
        _p(20.000, 73, 0, session: 'a'),
        _p(20.001, 73, 10, session: 'a'),
        _p(20.0011, 73, 20, session: 'b'),
        _p(20.0021, 73, 30, session: 'b'),
      ]);

      expect(analysis.lines, hasLength(2));
      expect(analysis.jumpCount, 0);
    });

    test('a single good point has a marker but no line', () {
      final analysis = RouteGeometry.analyse([_p(20, 73, 0)]);

      expect(analysis.lines, isEmpty);
      expect(analysis.first, isNotNull);
      expect(analysis.hasAnythingToDraw, isTrue);
    });

    test('no points, or only flagged ones, is handled', () {
      final none = RouteGeometry.analyse(const <RoutePoint>[]);
      expect(none.hasAnythingToDraw, isFalse);
      expect(none.first, isNull);
      expect(none.framePoints, isEmpty);

      final onlyFake = RouteGeometry.analyse([_p(20, 73, 0, isMock: true)]);
      expect(onlyFake.first, isNull);
      expect(onlyFake.hasAnythingToDraw, isTrue, reason: 'flagged points show');
      expect(onlyFake.framePoints, hasLength(1));
    });

    test(
      'the points to frame include the line, the ends and the flagged ones',
      () {
        final analysis = RouteGeometry.analyse([
          _p(20.000, 73, 0),
          _p(20.001, 73, 10),
          _p(21, 74, 15, isMock: true),
          _p(20.0, 73.0002, 20, accuracy: 300),
        ]);

        expect(analysis.framePoints.any((p) => p.latitude == 21), isTrue);
        expect(analysis.framePoints.any((p) => p.longitude == 73.0002), isTrue);
      },
    );
  });

  group('simplify (for drawing only)', () {
    test('keeps the ends and drops points on a straight line', () {
      final line = [for (var i = 0; i < 50; i++) _p(20 + i * 0.0001, 73, i)];

      final simple = RouteGeometry.simplify(line, 10);

      expect(simple, hasLength(2));
      expect(simple.first, same(line.first));
      expect(simple.last, same(line.last));
    });

    test('keeps a real corner', () {
      final line = [
        for (var i = 0; i <= 20; i++) _p(20 + i * 0.0001, 73, i),
        for (var i = 1; i <= 20; i++) _p(20.002, 73 + i * 0.0001, 20 + i),
      ];

      final simple = RouteGeometry.simplify(line, 10);

      expect(simple, hasLength(3));
      expect(simple[1].latitude, closeTo(20.002, 1e-9));
      expect(simple[1].longitude, closeTo(73, 1e-9));
    });

    test('never moves a kept point and keeps time order', () {
      final line = [
        for (var i = 0; i < 200; i++)
          _p(20 + i * 0.0001, 73 + (i % 7) * 0.00005, i),
      ];

      final simple = RouteGeometry.simplify(line, 3);

      for (final p in simple) {
        expect(line.contains(p), isTrue);
      }
      for (var i = 1; i < simple.length; i++) {
        expect(simple[i].recordedAt.isAfter(simple[i - 1].recordedAt), isTrue);
      }
    });

    test('two points, or fewer, are returned as they are', () {
      expect(RouteGeometry.simplify([_p(20, 73, 0)], 10), hasLength(1));
      expect(
        RouteGeometry.simplify([_p(20, 73, 0), _p(20.1, 73, 1)], 10),
        hasLength(2),
      );
    });

    test('a point that does not move at all does not break it', () {
      final line = [for (var i = 0; i < 10; i++) _p(20, 73, i)];

      expect(RouteGeometry.simplify(line, 10), hasLength(2));
    });
  });

  group('a long day (PRD: 3,000 points load within 5 seconds)', () {
    // A 10-hour day walked as a wandering line, one point every 12 seconds.
    List<RoutePoint> longDay(int count) => [
      for (var i = 0; i < count; i++)
        _p(
          20 + i * 0.00002,
          73 + 0.003 * (i % 40 < 20 ? i % 20 : 20 - i % 20) / 20,
          i * 12,
        ),
    ];

    test('3,000 points are analysed quickly, and far fewer are drawn', () {
      final points = longDay(3000);
      final timer = Stopwatch()..start();

      final analysis = RouteGeometry.analyse(points);

      timer.stop();
      final drawn = analysis.lines.fold<int>(0, (n, l) => n + l.length);
      expect(timer.elapsedMilliseconds, lessThan(1000));
      expect(drawn, lessThan(points.length));
      expect(
        analysis.goodPointCount,
        3000,
        reason: 'the stored data is untouched',
      );
    });

    test('a day over 10,000 points is simplified harder, still quickly', () {
      final points = longDay(12000);
      final timer = Stopwatch()..start();

      final analysis = RouteGeometry.analyse(points);

      timer.stop();
      expect(timer.elapsedMilliseconds, lessThan(3000));
      expect(analysis.goodPointCount, 12000);
    });
  });
}
