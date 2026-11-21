import 'dart:async';
import 'dart:io';

import '../logging/app_log.dart';

/// Reads the current time from the server.
typedef ServerTimeSource = Future<DateTime> Function();

/// Time elapsed since the timer was made, so tests can drive it.
abstract interface class ElapsedTimer {
  Duration get elapsed;
}

/// Reads the phone's uptime in seconds, or null when it cannot be read.
typedef UptimeReader = Duration? Function();

Duration? _readProcUptime() {
  try {
    final String first = File('/proc/uptime')
        .readAsStringSync()
        .trim()
        .split(' ')
        .first;
    return Duration(milliseconds: (double.parse(first) * 1000).round());
  } on Object {
    return null;
  }
}

/// Elapsed time that keeps counting while the phone is asleep.
///
/// Dart's [Stopwatch] is monotonic, and on Android that clock stops in deep
/// sleep, so after a night in the pocket it is hours behind. The kernel's
/// uptime (`/proc/uptime`, the same file the tracker uses) includes sleep. The
/// larger of the two is used, so a failed read just means the stopwatch.
class AwakeElapsedTimer implements ElapsedTimer {
  AwakeElapsedTimer({UptimeReader? uptime})
    : _uptime = uptime ?? _readProcUptime {
    _startUptime = _uptime();
    _watch.start();
  }

  final UptimeReader _uptime;
  final Stopwatch _watch = Stopwatch();
  Duration? _startUptime;

  @override
  Duration get elapsed {
    final Duration watch = _watch.elapsed;
    final Duration? start = _startUptime;
    final Duration? now = _uptime();
    if (start == null || now == null || now < start) return watch;
    final Duration sinceStart = now - start;
    return sinceStart > watch ? sinceStart : watch;
  }
}

/// The app's clock: the server's time, carried forward by a monotonic timer.
///
/// Why: the phone's clock can be changed by the user. After one successful
/// [sync], [now] is "server time at sync + time elapsed since then", measured
/// with a monotonic stopwatch that does not move when the phone's clock is
/// changed. Duty off while offline therefore still gets a correct time.
///
/// The server stays the final authority: duty on and duty off times are
/// stamped by the database. This clock is for what the phone must decide on
/// its own (enable the duty button, stop tracking at 11:00 PM offline).
///
/// Limitation: a phone restart resets the timer. Until the next sync,
/// [now] falls back to the phone's clock and [isSynced] is false, so callers
/// that must not trust the phone (duty on) require a fresh sync first.
class ServerClock {
  ServerClock({
    required this._source,
    ElapsedTimer? timer,
    DateTime Function()? phoneNow,
  }) : _timer = timer ?? AwakeElapsedTimer(),
       _phoneNow = phoneNow ?? DateTime.now;

  final ServerTimeSource _source;
  final ElapsedTimer _timer;
  final DateTime Function() _phoneNow;

  DateTime? _anchorServer;
  Duration _anchorElapsed = Duration.zero;

  bool get isSynced => _anchorServer != null;

  /// How long ago the last successful [sync] was, or null if there was none.
  Duration? get age => isSynced ? _timer.elapsed - _anchorElapsed : null;

  /// Syncs when there was no sync yet, or the last one is older than
  /// [maxAge]. Returns whether the clock is synced afterwards.
  Future<bool> syncIfStale(Duration maxAge) async {
    final Duration? current = age;
    if (current != null && current < maxAge) return true;
    return await sync() || isSynced;
  }

  /// Current time in UTC.
  DateTime now() {
    final DateTime? anchor = _anchorServer;
    if (anchor == null) {
      return _phoneNow().toUtc();
    }
    return anchor.add(_timer.elapsed - _anchorElapsed);
  }

  /// Fetches the server time. Half the round trip is added, because the server
  /// stamped its reply roughly in the middle of the request. Returns false on
  /// failure and keeps any earlier sync.
  Future<bool> sync() async {
    final Duration sent = _timer.elapsed;
    try {
      final DateTime server = (await _source()).toUtc();
      final Duration received = _timer.elapsed;
      final Duration roundTrip = received - sent;
      _anchorServer = server.add(roundTrip ~/ 2);
      _anchorElapsed = received;
      return true;
    } on Object catch (e, st) {
      AppLog.failure('ServerClock.sync', e, st);
      return false;
    }
  }
}
