/// Why the tracker is not recording right now.
enum TrackerProblem {
  /// Location (GPS) is switched off on the phone.
  locationOff('location_off'),

  /// Location permission was taken away.
  permissionOff('permission_off'),

  /// GPS gave an error.
  gps('gps');

  const TrackerProblem(this.wire);

  /// The name sent between the service and the app.
  final String wire;

  static TrackerProblem? fromWire(Object? value) {
    for (final TrackerProblem p in values) {
      if (p.wire == value) return p;
    }
    return null;
  }
}

/// What the tracker service tells the app after every check (about once a
/// minute): points still on the phone, internet, and why recording stopped.
class TrackerStatus {
  const TrackerStatus({
    this.pendingPoints = 0,
    this.offline = false,
    this.problem,
    this.problemSince,
  });

  /// Recorded points not yet uploaded.
  final int pendingPoints;

  /// The last upload failed (no internet).
  final bool offline;

  /// Set when recording has stopped.
  final TrackerProblem? problem;

  /// When [problem] started.
  final DateTime? problemSince;

  /// The message sent from the service to the app. Only strings, numbers
  /// and maps can cross between the two.
  Map<String, Object> toMessage() => <String, Object>{
    'status': true,
    'pending': pendingPoints,
    'offline': offline,
    if (problem case final TrackerProblem p) 'problem': p.wire,
    if (problemSince case final DateTime t)
      'since': t.toUtc().millisecondsSinceEpoch,
  };

  /// The status in a message from the service, or null when it is another
  /// kind of message.
  static TrackerStatus? fromMessage(Object? data) {
    if (data is! Map || data['status'] != true) return null;
    final Object? pending = data['pending'];
    final Object? since = data['since'];
    final TrackerProblem? problem = TrackerProblem.fromWire(data['problem']);
    return TrackerStatus(
      pendingPoints: pending is int && pending > 0 ? pending : 0,
      offline: data['offline'] == true,
      problem: problem,
      problemSince: problem != null && since is int
          ? DateTime.fromMillisecondsSinceEpoch(since, isUtc: true)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TrackerStatus &&
      other.pendingPoints == pendingPoints &&
      other.offline == offline &&
      other.problem == problem &&
      other.problemSince == problemSince;

  @override
  int get hashCode =>
      Object.hash(pendingPoints, offline, problem, problemSince);
}
