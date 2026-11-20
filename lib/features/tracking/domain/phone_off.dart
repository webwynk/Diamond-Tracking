import 'track_break.dart';

/// The tracker's "still alive" mark, written every minute.
class Heartbeat {
  const Heartbeat({
    required this.dayId,
    required this.at,
    required this.uptime,
    this.bootId,
  });

  factory Heartbeat.fromJson(Map<String, Object?> json) => Heartbeat(
    dayId: json['day_id']! as int,
    at: DateTime.parse(json['at']! as String).toUtc(),
    uptime: Duration(milliseconds: json['uptime_ms']! as int),
    bootId: json['boot_id'] as String?,
  );

  final int dayId;
  final DateTime at;

  /// Time since the phone started, when the mark was written.
  final Duration uptime;

  /// Android's id for the current boot, if readable.
  final String? bootId;

  Map<String, Object?> toJson() => <String, Object?>{
    'day_id': dayId,
    'at': at.toUtc().toIso8601String(),
    'uptime_ms': uptime.inMilliseconds,
    'boot_id': bootId,
  };
}

/// Works out, when the tracker starts again, whether tracking was missing.
///
/// If the phone restarted since [last] (a new boot id, or less uptime than
/// before), the phone was off from the last mark until it booted again:
/// boot time is [now] minus [uptime]. Otherwise the phone stayed on and only
/// the tracker was stopped, from the last mark until [now]. Breaks shorter
/// than [minimum] are not worth showing (one missed mark is normal).
TrackBreak? breakSince(
  Heartbeat? last, {
  required int dayId,
  required DateTime now,
  required Duration uptime,
  String? bootId,
  Duration minimum = const Duration(minutes: 5),
}) {
  if (last == null || last.dayId != dayId || !now.isAfter(last.at)) {
    return null;
  }
  final bool rebooted = (bootId != null && last.bootId != null)
      ? bootId != last.bootId
      : uptime < last.uptime;
  final TrackBreak result;
  if (rebooted) {
    DateTime bootAt = now.subtract(uptime);
    if (bootAt.isBefore(last.at)) bootAt = now;
    result = TrackBreak(
      from: last.at,
      to: bootAt,
      kind: TrackBreakKind.phoneOff,
    );
  } else {
    result = TrackBreak(
      from: last.at,
      to: now,
      kind: TrackBreakKind.trackingStopped,
    );
  }
  return result.length >= minimum ? result : null;
}
