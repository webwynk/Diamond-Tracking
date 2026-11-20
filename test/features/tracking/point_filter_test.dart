import 'package:diamond_tracking/features/tracking/domain/point_filter.dart';
import 'package:diamond_tracking/features/tracking/domain/track_fix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime t0 = DateTime.utc(2026, 11, 20, 2);
  // About 0.0001 degrees of latitude is 11 m.
  TrackFix fix(int seconds, double northM, {double accuracy = 8}) => TrackFix(
    time: t0.add(Duration(seconds: seconds)),
    latitude: 22.5 + northM / 111195,
    longitude: 88.3,
    accuracyM: accuracy,
  );

  test('keeps the first fix, then only real movement', () {
    final PointFilter f = PointFilter();
    expect(f.accept(fix(0, 0)), isTrue);
    expect(f.accept(fix(30, 5)), isFalse, reason: 'jitter');
    expect(f.accept(fix(60, 25)), isTrue, reason: 'moved 25 m');
  });

  test('keeps a fix every 3 minutes when standing still', () {
    final PointFilter f = PointFilter();
    expect(f.accept(fix(0, 0)), isTrue);
    expect(f.accept(fix(150, 2)), isFalse);
    expect(f.accept(fix(180, 3)), isTrue);
  });

  test('a poor fix needs to move more than its own error', () {
    final PointFilter f = PointFilter();
    expect(f.accept(fix(0, 0)), isTrue);
    expect(f.accept(fix(30, 30, accuracy: 45)), isFalse);
    expect(f.accept(fix(60, 60, accuracy: 45)), isTrue);
  });

  test('drops very inaccurate and out-of-order fixes', () {
    final PointFilter f = PointFilter();
    expect(f.accept(fix(0, 0, accuracy: 900)), isFalse);
    expect(f.accept(fix(60, 0)), isTrue);
    expect(f.accept(fix(30, 500)), isFalse);
  });

  test('distance matches the database formula', () {
    expect(PointFilter.distanceM(0, 0, 1, 0).round(), 111195);
  });
}
