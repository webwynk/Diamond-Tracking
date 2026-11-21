import '../../tracking/domain/track_break.dart';
import 'geo_point.dart';

/// A place where the employee stayed within 200 m for 15 minutes or more.
class RouteStop {
  const RouteStop({
    required this.point,
    required this.start,
    required this.end,
    this.address,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
    point: GeoPoint(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
    ),
    start: DateTime.parse(json['start'] as String).toUtc(),
    end: DateTime.parse(json['end'] as String).toUtc(),
    address: json['address'] as String?,
  );

  final GeoPoint point;
  final DateTime start;
  final DateTime end;

  /// Short address, once it has been looked up.
  final String? address;

  Duration get length => end.difference(start);
}

/// Why the route has a hole.
enum NoteKind {
  /// The phone was switched off.
  phoneOff,

  /// The phone was on, but the phone stopped the tracker.
  trackingStopped,

  /// No location for 15+ minutes, cause unknown (indoors, GPS off).
  noLocation,
}

/// A hole in the route, explained.
class RouteNote {
  const RouteNote({required this.from, required this.to, required this.kind});

  final DateTime from;
  final DateTime to;
  final NoteKind kind;

  String get label => switch (kind) {
    NoteKind.phoneOff => 'Phone was off',
    NoteKind.trackingStopped => 'Tracking was stopped by the phone',
    NoteKind.noLocation => 'No location',
  };
}

/// One day's route as the database built it.
class DayRoute {
  const DayRoute({
    required this.dayId,
    required this.segments,
    required this.stops,
    required this.notes,
    required this.distanceM,
    required this.pointCount,
    this.mockedPoints = 0,
  });

  /// Builds the route from a day_routes row and the day's reported breaks.
  factory DayRoute.fromRow(Map<String, dynamic> row, List<TrackBreak> breaks) {
    final List<RouteNote> gaps = <RouteNote>[
      for (final Object? g
          in row['gaps'] as List<Object?>? ?? const <Object?>[])
        if (g is Map<String, dynamic>)
          RouteNote(
            from: DateTime.parse(g['from'] as String).toUtc(),
            to: DateTime.parse(g['to'] as String).toUtc(),
            kind: NoteKind.noLocation,
          ),
    ];
    return DayRoute(
      dayId: (row['duty_day_id'] as num).toInt(),
      segments: <List<GeoPoint>>[
        for (final Object? s
            in row['segments'] as List<Object?>? ?? const <Object?>[])
          if (s is String) decodePolyline(s),
      ],
      stops: <RouteStop>[
        for (final Object? s
            in row['stops'] as List<Object?>? ?? const <Object?>[])
          if (s is Map<String, dynamic>) RouteStop.fromJson(s),
      ],
      notes: explainGaps(gaps, breaks),
      distanceM: (row['distance_m'] as num?)?.toInt() ?? 0,
      pointCount: (row['point_count'] as num?)?.toInt() ?? 0,
      mockedPoints: (row['mocked_points'] as num?)?.toInt() ?? 0,
    );
  }

  final int dayId;

  /// Continuous stretches of the route, split where it has a hole.
  final List<List<GeoPoint>> segments;
  final List<RouteStop> stops;
  final List<RouteNote> notes;
  final int distanceM;
  final int pointCount;

  /// Points that came from a fake-location app. They are not in the route,
  /// the distance or the stops.
  final int mockedPoints;

  bool get isEmpty => segments.every((List<GeoPoint> s) => s.isEmpty);

  List<GeoPoint> get allPoints => <GeoPoint>[
    for (final List<GeoPoint> s in segments) ...s,
  ];

  GeoPoint? get start => isEmpty ? null : allPoints.first;
  GeoPoint? get end => isEmpty ? null : allPoints.last;

  bool get needsAddresses => stops.any((RouteStop s) => s.address == null);
}

/// Every reported break becomes a note (the phone knows why it stopped).
/// Holes in the route that no break explains are "No location".
List<RouteNote> explainGaps(List<RouteNote> gaps, List<TrackBreak> breaks) {
  final List<RouteNote> notes = <RouteNote>[
    for (final TrackBreak b in breaks)
      RouteNote(
        from: b.from,
        to: b.to,
        kind: b.kind == TrackBreakKind.phoneOff
            ? NoteKind.phoneOff
            : NoteKind.trackingStopped,
      ),
  ];
  for (final RouteNote gap in gaps) {
    final bool explained = breaks.any(
      (TrackBreak b) => b.from.isBefore(gap.to) && b.to.isAfter(gap.from),
    );
    if (!explained) notes.add(gap);
  }
  notes.sort((RouteNote a, RouteNote b) => a.from.compareTo(b.from));
  return notes;
}
