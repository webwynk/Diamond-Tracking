import 'dart:async';

import '../logging/app_log.dart';

/// Reads the current time from the server.
typedef ServerTimeSource = Future<DateTime> Function();

/// A monotonic stopwatch, so tests can drive elapsed time.
abstract interface class ElapsedTimer {
  Duration get elapsed;
}

class _SystemElapsedTimer implements ElapsedTimer {
  _SystemElapsedTimer() : _watch = Stopwatch()..start();
  final Stopwatch _watch;
  @override
  Duration get elapsed => _watch.elapsed;
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
/// Limitation: a phone restart resets the stopwatch. Until the next sync,
/// [now] falls back to the phone's clock and [isSynced] is false, so callers
/// that must not trust the phone (duty on) require a fresh sync first.
class ServerClock {
  ServerClock({
    required this._source,
    ElapsedTimer? timer,
    DateTime Function()? phoneNow,
  }) : _timer = timer ?? _SystemElapsedTimer(),
       _phoneNow = phoneNow ?? DateTime.now;

  final ServerTimeSource _source;
  final ElapsedTimer _timer;
  final DateTime Function() _phoneNow;

  DateTime? _anchorServer;
  Duration _anchorElapsed = Duration.zero;

  bool get isSynced => _anchorServer != null;

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
