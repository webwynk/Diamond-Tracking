/// Why tracking stopped for a while during a duty.
enum TrackBreakKind {
  /// The phone was switched off (or restarted).
  phoneOff('phone_off'),

  /// The phone stayed on, but the tracker was stopped (battery saver, the
  /// app was force stopped).
  trackingStopped('tracking_stopped');

  const TrackBreakKind(this.wire);

  /// The value the database uses.
  final String wire;

  static TrackBreakKind fromWire(String value) =>
      TrackBreakKind.values.firstWhere((TrackBreakKind k) => k.wire == value);
}

/// A time span with no tracking, shown on the route as
/// "Phone was off 2:10 PM to 3:05 PM".
class TrackBreak {
  const TrackBreak({required this.from, required this.to, required this.kind});

  final DateTime from;
  final DateTime to;
  final TrackBreakKind kind;

  Duration get length => to.difference(from);

  @override
  bool operator ==(Object other) =>
      other is TrackBreak &&
      other.from == from &&
      other.to == to &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(from, to, kind);

  @override
  String toString() => 'TrackBreak(${kind.wire} $from to $to)';
}
