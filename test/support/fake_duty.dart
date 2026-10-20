import 'dart:async';

import 'package:diamond_tracking/core/services/tracker_engine.dart';
import 'package:diamond_tracking/core/services/tracking_service.dart';
import 'package:diamond_tracking/core/services/tracking_uploader.dart';
import 'package:diamond_tracking/domain/entities/duty_session.dart';
import 'package:diamond_tracking/domain/entities/location_point.dart';
import 'package:diamond_tracking/domain/entities/point_ingest_result.dart';
import 'package:diamond_tracking/domain/repositories/duty_repository.dart';
import 'package:diamond_tracking/domain/repositories/tracking_queue_store.dart';

/// Test-only [DutyRepository] standing in for the server. Set [startError] or
/// [endError] to make that call fail the way the real repository does.
class FakeDutyRepository implements DutyRepository {
  DutySession? mockActiveSession;
  DutySession? mockYesterdaySession;
  List<DutySession> mockHistory = [];

  Exception? readError;
  Exception? startError;
  Exception? endError;

  /// Names of the calls received, in order, for assertions.
  final List<String> calls = <String>[];

  @override
  Future<DutySession?> getActiveDutySession({
    required String employeeId,
  }) async {
    final error = readError;
    if (error != null) throw error;
    return mockActiveSession;
  }

  @override
  Future<DutySession> startDutySession({required String employeeId}) async {
    calls.add('startDutySession');
    final error = startError;
    if (error != null) throw error;

    // BR-4: starting again returns the session that is already open.
    final open = mockActiveSession;
    if (open != null) return open;

    final now = DateTime.now().toUtc();
    final session = DutySession(
      id: 'session_mock_1',
      employeeId: employeeId,
      startedAt: now,
      status: DutySessionStatus.open,
    );
    mockActiveSession = session;
    return session;
  }

  @override
  Future<DutySession> endDutySession({
    required String sessionId,
    String? endReason,
    String? notes,
  }) async {
    calls.add('endDutySession');
    final error = endError;
    if (error != null) throw error;

    final session =
        mockActiveSession ??
        DutySession(
          id: sessionId,
          employeeId: 'emp_1',
          startedAt: DateTime.now().toUtc().subtract(const Duration(hours: 4)),
          status: DutySessionStatus.completed,
        );
    final completed = session.copyWith(
      status: DutySessionStatus.completed,
      endedAt: DateTime.now().toUtc(),
      endReason: endReason ?? 'normal',
    );
    mockActiveSession = null;
    return completed;
  }

  @override
  Future<DutySession?> getYesterdayDutySession({
    required String employeeId,
  }) async {
    return mockYesterdaySession;
  }

  @override
  Future<List<DutySession>> getDutyHistory({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
    int offset = 0,
  }) async {
    return mockHistory;
  }

  /// How far the server's clock is ahead of the phone's (negative: behind).
  Duration serverClockAhead = Duration.zero;

  @override
  Future<DateTime> getServerTime() async {
    calls.add('getServerTime');
    return DateTime.now().toUtc().add(serverClockAhead);
  }

  /// Decides the server's answer to an upload; by default it stores everything.
  Future<PointIngestResult> Function(List<LocationPoint> points)? ingestHandler;

  /// Every batch received, in order, for assertions.
  final List<List<LocationPoint>> ingestedBatches = <List<LocationPoint>>[];

  @override
  Future<PointIngestResult> ingestLocationPoints({
    required List<LocationPoint> points,
  }) async {
    calls.add('ingestLocationPoints');
    ingestedBatches.add(List<LocationPoint>.of(points));
    final handler = ingestHandler;
    if (handler != null) return handler(points);
    return PointIngestResult(confirmedIds: {for (final p in points) p.id});
  }

  /// All GPS statuses reported via [reportGpsStatus], in order.
  final List<bool> reportedGpsStatuses = <bool>[];

  @override
  Future<bool> reportGpsStatus({required bool enabled}) async {
    calls.add('reportGpsStatus');
    reportedGpsStatuses.add(enabled);
    return true;
  }
}

/// Test-only [TrackingService]: no GPS and no Android service. Points are
/// pushed with [emitPoint]; set [startResult] to false to simulate a tracker
/// that cannot start; [tracking] is what "the service is running" reports.
class FakeTrackingService implements TrackingService {
  final _controller = StreamController<LocationPoint>.broadcast();
  final _stops = StreamController<TrackerStopReason>.broadcast();
  final _notices = StreamController<TrackerNotice>.broadcast();
  bool tracking = false;

  /// True once [clearLocalData] was called (sign-out).
  bool localDataCleared = false;
  bool startResult = true;
  int queuedCount = 0;

  /// The session the app asked the service to track, for assertions.
  ActiveTrackingSession? startedWith;

  bool get isTracking => tracking;

  @override
  Stream<LocationPoint> get pointStream => _controller.stream;

  @override
  Stream<TrackerStopReason> get stopStream => _stops.stream;

  @override
  Stream<TrackerNotice> get noticeStream => _notices.stream;

  @override
  Future<bool> startTracking({required ActiveTrackingSession session}) async {
    startedWith = session;
    tracking = startResult;
    return startResult;
  }

  @override
  Future<void> stopTracking() async {
    tracking = false;
  }

  @override
  Future<bool> isTrackerRunning() async => tracking;

  @override
  Future<int> getQueuedPointsCount() async => queuedCount;

  @override
  Future<void> clearLocalData() async {
    tracking = false;
    queuedCount = 0;
    localDataCleared = true;
  }

  void emitPoint(LocationPoint point) {
    queuedCount++;
    _controller.add(point);
  }

  /// The tracker has something to tell the employee.
  void emitNotice(TrackerNotice notice) => _notices.add(notice);

  /// The tracker stopped by itself.
  void emitStop(TrackerStopReason reason) {
    tracking = false;
    _stops.add(reason);
  }
}

/// Test-only stand-in for [TrackingUploader] so duty tests never open the
/// on-phone database or start a timer. Pass the repository's `calls` list as
/// [log] to assert the order of uploads and server calls.
class FakeUploader implements TrackingUploader {
  FakeUploader({List<String>? log}) : calls = log ?? <String>[];

  final List<String> calls;
  bool _running = false;

  @override
  Duration get interval => const Duration(seconds: 60);

  @override
  int get batchSize => 100;

  @override
  int get consecutiveFailures => 0;

  @override
  UploadOutcome? lastOutcome;

  @override
  bool get isRunning => _running;

  @override
  void start() {
    _running = true;
    calls.add('uploader.start');
  }

  @override
  void stop() {
    _running = false;
    calls.add('uploader.stop');
  }

  @override
  Future<UploadOutcome> uploadPending() async {
    calls.add('uploader.uploadPending');
    return const UploadOutcome();
  }

  @override
  Future<UploadOutcome> flush({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    calls.add('uploader.flush');
    return const UploadOutcome();
  }
}
