import 'package:diamond_tracking/core/utils/id_generator.dart';
import 'package:diamond_tracking/core/utils/session_distance_estimator.dart';
import 'package:diamond_tracking/domain/entities/location_point.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 17, 4, 30);

LocationPoint _point(
  double lat,
  int secondsAfterStart, {
  double lon = 73.0,
  double accuracy = 5,
  bool isMock = false,
}) => LocationPoint(
  id: 'p-$lat-$secondsAfterStart',
  sessionId: 's1',
  latitude: lat,
  longitude: lon,
  accuracy: accuracy,
  recordedAt: _t0.add(Duration(seconds: secondsAfterStart)),
  isMock: isMock,
);

void main() {
  group('IdGenerator.uuidV4', () {
    test('has the version 4 UUID shape', () {
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      for (var i = 0; i < 200; i++) {
        expect(IdGenerator.uuidV4(), matches(uuid));
      }
    });

    test('does not repeat, even for ids made in the same millisecond', () {
      final ids = <String>{for (var i = 0; i < 5000; i++) IdGenerator.uuidV4()};
      expect(ids.length, 5000);
    });
  });

  group(
    'SessionDistanceEstimator (mirrors the server rules, BR-8 / BR-10)',
    () {
      test('three points 0.001 degrees apart add up to about 0.222 km', () {
        // Same figure the database attack check expects from the server.
        final estimator = SessionDistanceEstimator();
        estimator
          ..add(_point(20.000, 0))
          ..add(_point(20.001, 60));
        final total = estimator.add(_point(20.002, 120));

        expect(total, closeTo(0.2224, 0.002));
        expect(estimator.totalKm, total);
      });

      test('the first point alone is zero distance', () {
        expect(SessionDistanceEstimator().add(_point(20.0, 0)), 0.0);
      });

      test('mock points and poor-accuracy points are ignored', () {
        final estimator = SessionDistanceEstimator()..add(_point(20.000, 0));

        estimator.add(_point(20.001, 60, isMock: true));
        estimator.add(_point(20.001, 60, accuracy: 150));
        expect(estimator.totalKm, 0.0);

        estimator.add(_point(20.001, 60));
        expect(estimator.totalKm, closeTo(0.1112, 0.002));
      });

      test(
        'an impossible jump (over 55 m/s) is not counted, later movement is',
        () {
          final estimator = SessionDistanceEstimator()
            ..add(_point(20.0, 0))
            ..add(_point(21.0, 60)); // about 111 km in a minute

          expect(estimator.totalKm, 0.0);

          estimator.add(_point(21.001, 120));
          expect(estimator.totalKm, closeTo(0.1112, 0.002));
        },
      );

      test('points with the same or an earlier timestamp are not counted', () {
        final estimator = SessionDistanceEstimator()
          ..add(_point(20.000, 60))
          ..add(_point(20.001, 60))
          ..add(_point(20.002, 30));

        expect(estimator.totalKm, 0.0);
      });
    },
  );
}
