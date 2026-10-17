import 'dart:async';
import 'dart:math';

import '../../domain/repositories/duty_repository.dart';
import '../../domain/repositories/tracking_queue_store.dart';
import '../errors/app_exceptions.dart';

/// How long to wait after a failed upload: 15 s, doubling each time up to
/// 10 minutes, with a little randomness so many phones that regain signal
/// together do not all retry at the same instant. Never a tight retry loop
/// (docs/08 section 6): it would drain the battery.
class BackoffPolicy {
  BackoffPolicy({Random? random}) : _random = random ?? Random();

  static const Duration first = Duration(seconds: 15);
  static const Duration maximum = Duration(minutes: 10);

  final Random _random;

  /// The wait after the [failures]-th failure in a row (1 for the first).
  Duration delayAfter(int failures) {
    final doublings = (failures - 1).clamp(0, 20);
    final base = first.inMilliseconds * pow(2, doublings);
    final jittered = base * (0.8 + _random.nextDouble() * 0.4);
    return Duration(
      milliseconds: min(jittered, maximum.inMilliseconds.toDouble()).round(),
    );
  }
}

/// What one pass over the waiting points achieved.
class UploadOutcome {
  const UploadOutcome({
    this.confirmed = 0,
    this.rejected = 0,
    this.queueEmpty = true,
    this.failure,
    this.refusedSessionIds = const <String>{},
  });

  /// Points the server now holds (and the phone has deleted).
  final int confirmed;

  /// Points the server refused for good (discarded and counted).
  final int rejected;

  /// True when nothing is left waiting.
  final bool queueEmpty;

  /// Why the pass stopped early, or null when it ran to the end.
  final AppException? failure;

  /// Sessions for which the server refused points because the session is
  /// closed or not the caller's: the tracker should stop recording for them.
  final Set<String> refusedSessionIds;

  bool get failed => failure != null;

  /// The employee must sign in again before anything can be uploaded.
  bool get needsSignIn => failure is UnauthorizedRoleException;
}

/// Sends the points waiting on the phone to the server, safely.
///
/// - A point leaves the phone only after the server confirms it.
/// - Failures back off ([BackoffPolicy]); a rejected point is discarded and
///   counted so one bad point never blocks the queue.
/// - One pass at a time: overlapping calls share the pass already running.
class TrackingUploader {
  TrackingUploader({
    required this._queue,
    required this._ingestor,
    BackoffPolicy? backoff,
    this.interval = const Duration(seconds: 60),
    this.batchSize = 100,
    Future<void> Function(Duration)? delay,
  }) : _backoff = backoff ?? BackoffPolicy(),
       _delay = delay ?? Future<void>.delayed;

  /// How often to look for waiting points while everything is going well.
  final Duration interval;

  /// Points per request. The server accepts at most 200.
  final int batchSize;

  final TrackingQueueStore _queue;
  final DutyRepository _ingestor;
  final BackoffPolicy _backoff;
  final Future<void> Function(Duration) _delay;

  static const Set<String> _sessionRefusals = <String>{
    'point_outside_session',
    'session_not_found',
  };

  Future<UploadOutcome>? _inFlight;
  int _consecutiveFailures = 0;
  UploadOutcome? _lastOutcome;
  bool _running = false;
  int _generation = 0;
  Completer<void>? _wake;

  /// How the most recent pass ended, or null before the first pass.
  UploadOutcome? get lastOutcome => _lastOutcome;

  /// Failed passes in a row; resets to zero after a clean pass.
  int get consecutiveFailures => _consecutiveFailures;

  bool get isRunning => _running;

  /// Uploads everything waiting, oldest first, until the queue is empty or a
  /// request fails.
  Future<UploadOutcome> uploadPending() {
    return _inFlight ??= _drain()
        .then((outcome) => _lastOutcome = outcome)
        .whenComplete(() => _inFlight = null);
  }

  /// Like [uploadPending] but gives up waiting after [timeout]. Used right
  /// before duty ends, so the server's distance includes the latest points
  /// without a bad connection holding the employee up. The pass keeps going in
  /// the background; anything it misses is accepted later (late uploads into a
  /// closed session are allowed and recounted by the server).
  Future<UploadOutcome> flush({
    Duration timeout = const Duration(seconds: 10),
  }) {
    return uploadPending().timeout(
      timeout,
      onTimeout: () =>
          const UploadOutcome(queueEmpty: false, failure: NetworkException()),
    );
  }

  /// Starts uploading in the background, once a minute (sooner after a wake-up,
  /// later after failures). Safe to call again.
  void start() {
    if (_running) return;
    _running = true;
    unawaited(_loop(++_generation));
  }

  /// Stops the background loop. Points stay safely on the phone.
  void stop() {
    _running = false;
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  Future<void> _loop(int generation) async {
    // A stop() followed by start() must not leave two loops running.
    bool current() => _running && generation == _generation;

    while (current()) {
      final outcome = await uploadPending();
      if (!current()) break;

      final wait = outcome.failed
          ? _backoff.delayAfter(_consecutiveFailures)
          : interval;
      _wake = Completer<void>();
      await Future.any<void>(<Future<void>>[_delay(wait), _wake!.future]);
    }
  }

  Future<UploadOutcome> _drain() async {
    var confirmed = 0;
    var rejected = 0;
    final refused = <String>{};

    try {
      while (true) {
        final batch = await _queue.nextBatch(limit: batchSize);
        if (batch.isEmpty) {
          _consecutiveFailures = 0;
          return UploadOutcome(
            confirmed: confirmed,
            rejected: rejected,
            refusedSessionIds: refused,
          );
        }

        final result = await _ingestor.ingestLocationPoints(points: batch);

        // Only act on points that were in this batch: an answer about some
        // other id must not count as progress or delete anything.
        final batchIds = <String>{for (final p in batch) p.id};
        final confirmedHere = result.confirmedIds.intersection(batchIds);
        final rejectedHere = <String>{
          for (final id in result.rejected.keys)
            if (batchIds.contains(id)) id,
        };

        await _queue.removeConfirmedPoints(confirmedHere.toList());
        await _queue.discardRejectedPoints(rejectedHere.toList());
        confirmed += confirmedHere.length;
        rejected += rejectedHere.length;

        for (final point in batch) {
          if (_sessionRefusals.contains(result.rejected[point.id])) {
            refused.add(point.sessionId);
          }
        }

        if (confirmedHere.isEmpty && rejectedHere.isEmpty) {
          // The server answered but settled none of these points. Stop rather
          // than ask the same question forever; they stay on the phone.
          throw const ServerException(
            'The server did not confirm any of the points.',
          );
        }
        _consecutiveFailures = 0;
      }
    } on AppException catch (e) {
      return _failed(e, confirmed, rejected, refused);
    } catch (_) {
      // A storage or parsing problem must not kill the background loop.
      return _failed(
        const ServerException('Could not upload location points.'),
        confirmed,
        rejected,
        refused,
      );
    }
  }

  UploadOutcome _failed(
    AppException failure,
    int confirmed,
    int rejected,
    Set<String> refused,
  ) {
    _consecutiveFailures++;
    return UploadOutcome(
      confirmed: confirmed,
      rejected: rejected,
      queueEmpty: false,
      failure: failure,
      refusedSessionIds: refused,
    );
  }
}
