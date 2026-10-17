import 'package:diamond_tracking/domain/entities/live_position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 17, 8, 0);

  LivePosition at(Duration ago, {bool isMock = false}) => LivePosition(
    employeeId: 'e1',
    sessionId: 's1',
    latitude: 19.9,
    longitude: 73.8,
    recordedAt: now.subtract(ago),
    isMock: isMock,
  );

  group('LivePosition.statusAt (PRD section 3 status table)', () {
    test('a fresh point is active', () {
      expect(at(const Duration(seconds: 30)).statusAt(now), LiveStatus.active);
    });

    test('exactly 5 minutes old is still active, over 5 is stale', () {
      expect(at(const Duration(minutes: 5)).statusAt(now), LiveStatus.active);
      expect(
        at(const Duration(minutes: 5, seconds: 1)).statusAt(now),
        LiveStatus.stale,
      );
    });

    test('a mock-flagged point is suspect, even when it is also old', () {
      expect(
        at(const Duration(seconds: 5), isMock: true).statusAt(now),
        LiveStatus.suspect,
      );
      expect(
        at(const Duration(hours: 1), isMock: true).statusAt(now),
        LiveStatus.suspect,
      );
    });
  });

  group('LivePosition.tryParse', () {
    Map<String, dynamic> row() => <String, dynamic>{
      'employee_id': 'e1',
      'session_id': 's1',
      'latitude': 19.9,
      'longitude': 73,
      'accuracy': 6,
      'battery_level': 81,
      'is_mock': false,
      'recorded_at': '2026-10-17T07:59:30+00:00',
      'updated_at': '2026-10-17T07:59:31+00:00',
    };

    test('reads a live_locations row, including whole-number coordinates', () {
      final position = LivePosition.tryParse(row())!;
      expect(position.employeeId, 'e1');
      expect(position.longitude, 73.0);
      expect(position.accuracy, 6.0);
      expect(position.batteryLevel, 81);
      expect(position.recordedAt, DateTime.utc(2026, 10, 17, 7, 59, 30));
    });

    test('accepts missing accuracy and battery', () {
      final json = row()
        ..remove('accuracy')
        ..['battery_level'] = null;
      final position = LivePosition.tryParse(json)!;
      expect(position.accuracy, isNull);
      expect(position.batteryLevel, isNull);
    });

    test('answers null for a row that cannot be a position', () {
      for (final key in const [
        'employee_id',
        'session_id',
        'latitude',
        'longitude',
        'recorded_at',
      ]) {
        expect(LivePosition.tryParse(row()..remove(key)), isNull, reason: key);
      }
      expect(
        LivePosition.tryParse(row()..['recorded_at'] = 'not a date'),
        isNull,
      );
      expect(LivePosition.tryParse(row()..['latitude'] = 'north'), isNull);
    });
  });
}
