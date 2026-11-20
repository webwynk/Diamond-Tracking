import 'dart:io';

import 'package:diamond_tracking/features/tracking/data/track_uploader.dart';
import 'package:diamond_tracking/features/tracking/domain/track_break.dart';

/// Records uploads. Set [offline] to fail like a lost connection, or
/// [reject] to refuse for good.
class FakeUploader implements TrackUploader {
  bool offline = false;
  bool reject = false;
  final List<List<Map<String, Object?>>> pointCalls =
      <List<Map<String, Object?>>>[];
  final List<TrackBreak> breaks = <TrackBreak>[];
  final List<DateTime> dutyOffs = <DateTime>[];
  final List<String> passes = <String>[];

  int get pointCount => pointCalls.fold(
    0,
    (int sum, List<Map<String, Object?>> c) => sum + c.length,
  );

  void _check() {
    if (offline) throw const SocketException('offline');
    if (reject) throw const UploadRejected('invalid_upload_pass');
  }

  @override
  Future<int> uploadPoints(
    int dayId,
    String pass,
    List<Map<String, Object?>> points,
  ) async {
    _check();
    passes.add(pass);
    pointCalls.add(points);
    return points.length;
  }

  @override
  Future<void> reportBreak(int dayId, String pass, TrackBreak b) async {
    _check();
    breaks.add(b);
  }

  @override
  Future<void> dutyOff(int dayId, String pass, DateTime offAt) async {
    _check();
    dutyOffs.add(offAt);
  }
}
