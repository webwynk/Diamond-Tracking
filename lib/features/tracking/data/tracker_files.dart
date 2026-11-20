import 'dart:convert';
import 'dart:io';

import '../../../core/logging/app_log.dart';
import '../domain/phone_off.dart';
import '../domain/tracking_session.dart';
import 'point_queue.dart';

/// The files the app and the tracker service share, in the app's private
/// folder (not backed up, not readable by other apps).
///
/// - `session.json`: written by the app only (duty on, resume, duty off).
/// - `state.json`: written by the service only (heartbeat, battery warnings).
/// - `queue/`: the offline point queue.
class TrackerFiles {
  TrackerFiles(this.root);

  final Directory root;

  File get _session => File('${root.path}/session.json');
  File get _state => File('${root.path}/state.json');

  late final PointQueue queue = PointQueue(Directory('${root.path}/queue'));

  TrackingSession? readSession() {
    final Map<String, Object?>? json = _read(_session);
    if (json == null) return null;
    try {
      return TrackingSession.fromJson(json);
    } on Object catch (e) {
      AppLog.failure('TrackerFiles.readSession', e);
      return null;
    }
  }

  void writeSession(TrackingSession session) =>
      _write(_session, session.toJson());

  void deleteSession() {
    if (_session.existsSync()) _session.deleteSync();
  }

  TrackerState readState() {
    final Map<String, Object?>? json = _read(_state);
    if (json == null) return const TrackerState();
    try {
      return TrackerState.fromJson(json);
    } on Object catch (e) {
      AppLog.failure('TrackerFiles.readState', e);
      return const TrackerState();
    }
  }

  void writeState(TrackerState state) => _write(_state, state.toJson());

  /// Everything, for sign out.
  void clear() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }

  static Map<String, Object?>? _read(File file) {
    if (!file.existsSync()) return null;
    try {
      final Object? value = jsonDecode(file.readAsStringSync());
      return value is Map<String, Object?> ? value : null;
    } on FormatException {
      return null;
    }
  }

  /// Write to a temporary file and rename, so a reader never sees half a file.
  void _write(File file, Map<String, Object?> json) {
    root.createSync(recursive: true);
    final File temp = File('${file.path}.tmp');
    temp.writeAsStringSync(jsonEncode(json), flush: true);
    temp.renameSync(file.path);
  }
}

/// What the service remembers between runs.
class TrackerState {
  const TrackerState({
    this.heartbeat,
    this.batteryDayId,
    this.batteryWarned = const <int>{},
    this.dutyOffSentFor,
  });

  factory TrackerState.fromJson(Map<String, Object?> json) {
    final Object? beat = json['heartbeat'];
    final Object? warned = json['battery_warned'];
    return TrackerState(
      heartbeat: beat is Map<String, Object?> ? Heartbeat.fromJson(beat) : null,
      batteryDayId: json['battery_day_id'] as int?,
      batteryWarned: warned is List<Object?>
          ? <int>{...warned.whereType<int>()}
          : const <int>{},
      dutyOffSentFor: json['duty_off_sent_for'] as int?,
    );
  }

  final Heartbeat? heartbeat;

  /// The duty day [batteryWarned] belongs to.
  final int? batteryDayId;

  /// Battery levels already warned about that day.
  final Set<int> batteryWarned;

  /// The duty day whose offline duty off the tracker has sent.
  final int? dutyOffSentFor;

  Set<int> warnedFor(int dayId) =>
      batteryDayId == dayId ? batteryWarned : const <int>{};

  TrackerState copyWith({
    Heartbeat? heartbeat,
    int? batteryDayId,
    Set<int>? batteryWarned,
    int? dutyOffSentFor,
  }) => TrackerState(
    heartbeat: heartbeat ?? this.heartbeat,
    batteryDayId: batteryDayId ?? this.batteryDayId,
    batteryWarned: batteryWarned ?? this.batteryWarned,
    dutyOffSentFor: dutyOffSentFor ?? this.dutyOffSentFor,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'heartbeat': heartbeat?.toJson(),
    'battery_day_id': batteryDayId,
    'battery_warned': batteryWarned.toList()..sort(),
    'duty_off_sent_for': dutyOffSentFor,
  };
}
