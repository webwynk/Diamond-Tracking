import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/routes/domain/day_route.dart';
import 'package:diamond_tracking/features/routes/domain/geo_point.dart';
import 'package:diamond_tracking/features/routes/domain/live_position.dart';
import 'package:diamond_tracking/features/routes/presentation/live_map_page.dart';
import 'package:diamond_tracking/features/tracking/domain/track_break.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  test('decodes Google\'s polyline example', () {
    // The same string the database test checks it writes.
    expect(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@'), const <GeoPoint>[
      GeoPoint(38.5, -120.2),
      GeoPoint(40.7, -120.95),
      GeoPoint(43.252, -126.453),
    ]);
    expect(decodePolyline(''), isEmpty);
    expect(() => decodePolyline('_p~iF~'), throwsFormatException);
  });

  final DateTime t = DateTime.utc(2026, 11, 20, 8);
  DateTime at(int min) => t.add(Duration(minutes: min));

  test('gaps are explained by the phone\'s reported breaks', () {
    final List<RouteNote> notes = explainGaps(
      <RouteNote>[
        RouteNote(from: at(0), to: at(60), kind: NoteKind.noLocation),
        RouteNote(from: at(120), to: at(150), kind: NoteKind.noLocation),
      ],
      <TrackBreak>[
        TrackBreak(from: at(2), to: at(58), kind: TrackBreakKind.phoneOff),
        TrackBreak(
          from: at(200),
          to: at(210),
          kind: TrackBreakKind.trackingStopped,
        ),
      ],
    );
    expect(notes.map((RouteNote n) => n.kind), <NoteKind>[
      NoteKind.phoneOff,
      NoteKind.noLocation,
      NoteKind.trackingStopped,
    ]);
    expect(notes.first.label, 'Phone was off');
  });

  test('reads a day_routes row', () {
    final DayRoute r = DayRoute.fromRow(<String, dynamic>{
      'duty_day_id': 9,
      'segments': <String>['_p~iF~ps|U_ulLnnqC'],
      'stops': <Map<String, dynamic>>[
        <String, dynamic>{
          'lat': 22.7,
          'lng': 88.4,
          'start': '2026-11-20T03:00:00+00:00',
          'end': '2026-11-20T03:40:00+00:00',
        },
      ],
      'gaps': <Map<String, dynamic>>[],
      'distance_m': 4200,
      'point_count': 52,
      'mocked_points': 3,
    }, const <TrackBreak>[]);
    expect(r.mockedPoints, 3);
    expect(r.segments.single, hasLength(2));
    expect(r.stops.single.length, const Duration(minutes: 40));
    expect(r.needsAddresses, isTrue);
    expect(r.start, const GeoPoint(38.5, -120.2));
  });

  test('live list: on duty first, stale after 5 minutes, names joined', () {
    final DateTime now = at(30);
    DutyDay day(int id, String user, DayStatus s) => DutyDay(
      id: id,
      userId: user,
      day: DateTime.utc(2026, 11, 20),
      status: s,
      dutyOnAt: at(-60),
    );
    final List<LiveRow> rows = liveRows(
      positions: <LivePosition>[
        LivePosition(
          userId: 'a',
          dutyDayId: 1,
          point: const GeoPoint(22.7, 88.4),
          recordedAt: at(29),
        ),
        LivePosition(
          userId: 'b',
          dutyDayId: 2,
          point: const GeoPoint(22.8, 88.4),
          recordedAt: at(10),
        ),
      ],
      days: <DutyDay>[
        day(3, 'c', DayStatus.pending),
        day(2, 'b', DayStatus.onDuty),
        day(1, 'a', DayStatus.onDuty),
        DutyDay(
          id: 4,
          userId: 'd',
          day: DateTime.utc(2026, 11, 20),
          status: DayStatus.leave,
        ),
      ],
      people: <Profile>[
        profile('a', name: 'Zara'),
        profile('b', name: 'Amit'),
        profile('c', name: 'Bina'),
      ],
      now: now,
    );
    expect(rows.map((LiveRow r) => r.name), <String>['Amit', 'Zara', 'Bina']);
    expect(rows[0].stale, isTrue);
    expect(rows[1].stale, isFalse);
    expect(rows[2].onDuty, isFalse);
  });
}
