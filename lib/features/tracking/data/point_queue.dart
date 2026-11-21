import 'dart:convert';
import 'dart:io';

import '../../../core/logging/app_log.dart';
import '../domain/track_break.dart';
import 'track_uploader.dart';

/// The offline queue: points and breaks wait here until they are uploaded.
///
/// Plain files in the app's private folder, so nothing is lost when the
/// phone has no signal, the app is closed, or the phone restarts.
///
/// - New records are appended to `open.jsonl`, one JSON object per line. Its
///   first line names the duty day and its upload pass.
/// - Before an upload the open file is renamed to `batch-<time>.jsonl`
///   (a rename is atomic, so a batch is always complete).
/// - A batch file is deleted only after the server accepted all of it.
///   Uploads are idempotent (the server skips duplicates), so sending a batch
///   twice after a crash is harmless.
///
/// One writer at a time: the tracker service while it runs, otherwise the
/// app (which only drains).
class PointQueue {
  PointQueue(this.dir);

  final Directory dir;

  /// The server takes at most 500 points per call.
  static const int chunkSize = 400;

  File get _open => File('${dir.path}/open.jsonl');

  void addPoint(int dayId, String pass, Map<String, Object?> point) =>
      _append(dayId, pass, point);

  void addBreak(int dayId, String pass, TrackBreak trackBreak) =>
      _append(dayId, pass, <String, Object?>{
        'brk': trackBreak.kind.wire,
        'f': trackBreak.from.toUtc().toIso8601String(),
        'to': trackBreak.to.toUtc().toIso8601String(),
      });

  void _append(int dayId, String pass, Map<String, Object?> record) {
    dir.createSync(recursive: true);
    final _Header? header = _readHeader(_open);
    if (header != null && (header.dayId != dayId || header.pass != pass)) {
      seal();
    }
    final StringBuffer out = StringBuffer();
    if (!_open.existsSync() || _open.lengthSync() == 0) {
      out.writeln(jsonEncode(<String, Object?>{'day': dayId, 'pass': pass}));
    }
    out.writeln(jsonEncode(record));
    _open.writeAsStringSync(out.toString(), mode: FileMode.append, flush: true);
  }

  /// Turns the open file into a batch, ready to upload.
  void seal() {
    if (!_open.existsSync()) return;
    final List<String> lines = _open.readAsLinesSync();
    if (lines.length < 2) {
      _open.deleteSync();
      return;
    }
    final String stamp = DateTime.now().microsecondsSinceEpoch
        .toString()
        .padLeft(18, '0');
    _open.renameSync('${dir.path}/batch-$stamp.jsonl');
  }

  /// Points and breaks not yet uploaded.
  int get pendingCount {
    if (!dir.existsSync()) return 0;
    int count = 0;
    for (final File f in _files()) {
      count += _records(f).length;
    }
    return count;
  }

  bool get isEmpty => pendingCount == 0;

  /// Uploads everything, oldest first. Stops at the first network error and
  /// keeps the rest for the next try.
  ///
  /// [passFor] gives the current upload pass of a duty day (null when the day
  /// is not the running duty). A batch is sent with it instead of the pass it
  /// was written with, so points queued before a password reset go up with
  /// the new pass. With [keepOnRefusedPass] a batch of the running duty that
  /// the server refuses because of its pass is kept, and the drain stops
  /// ([DrainResult.passRefused]): the app can still get a new pass.
  Future<DrainResult> drain(
    TrackUploader uploader, {
    String? Function(int dayId)? passFor,
    bool keepOnRefusedPass = false,
  }) async {
    if (!dir.existsSync()) return const DrainResult();
    seal();
    int sent = 0;
    int dropped = 0;
    for (final File file in _batches()) {
      final _Header? header = _readHeader(file);
      final List<Map<String, Object?>> records = _records(file);
      if (header == null) {
        file.deleteSync();
        continue;
      }
      final List<Map<String, Object?>> points = <Map<String, Object?>>[
        for (final Map<String, Object?> r in records)
          if (!r.containsKey('brk')) r,
      ];
      final List<TrackBreak> breaks = <TrackBreak>[
        for (final Map<String, Object?> r in records)
          if (r.containsKey('brk')) ?_breakFrom(r),
      ];
      final String currentPass = passFor?.call(header.dayId) ?? header.pass;
      try {
        for (int i = 0; i < points.length; i += chunkSize) {
          final int end = (i + chunkSize).clamp(0, points.length);
          await uploader.uploadPoints(
            header.dayId,
            currentPass,
            points.sublist(i, end),
          );
        }
        for (final TrackBreak b in breaks) {
          await uploader.reportBreak(header.dayId, currentPass, b);
        }
        sent += records.length;
      } on UploadRejected catch (e) {
        AppLog.failure('PointQueue.drain', e);
        if (keepOnRefusedPass &&
            e.reason == UploadRejected.badPass &&
            passFor?.call(header.dayId) != null) {
          return DrainResult(sent: sent, dropped: dropped, passRefused: true);
        }
        dropped += records.length;
      } on Object catch (e, st) {
        AppLog.failure('PointQueue.drain', e, st);
        return DrainResult(sent: sent, dropped: dropped, failed: true);
      }
      if (file.existsSync()) file.deleteSync();
    }
    return DrainResult(sent: sent, dropped: dropped);
  }

  /// Deletes everything (used when the account is signed out).
  void clear() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  List<File> _batches() {
    final List<File> files =
        dir
            .listSync()
            .whereType<File>()
            .where((File f) => f.uri.pathSegments.last.startsWith('batch-'))
            .toList()
          ..sort((File a, File b) => a.path.compareTo(b.path));
    return files;
  }

  List<File> _files() => <File>[..._batches(), if (_open.existsSync()) _open];

  static _Header? _readHeader(File file) {
    if (!file.existsSync()) return null;
    final List<String> lines = file.readAsLinesSync();
    if (lines.isEmpty) return null;
    final Map<String, Object?>? json = _decode(lines.first);
    final Object? day = json?['day'];
    final Object? pass = json?['pass'];
    if (day is! int || pass is! String) return null;
    return _Header(day, pass);
  }

  /// The records of a file, skipping the header and any line cut short by a
  /// crash mid-write.
  static List<Map<String, Object?>> _records(File file) {
    if (!file.existsSync()) return const <Map<String, Object?>>[];
    return <Map<String, Object?>>[
      for (final String line in file.readAsLinesSync().skip(1)) ?_decode(line),
    ];
  }

  static Map<String, Object?>? _decode(String line) {
    try {
      final Object? value = jsonDecode(line);
      return value is Map<String, Object?> ? value : null;
    } on FormatException {
      return null;
    }
  }

  static TrackBreak? _breakFrom(Map<String, Object?> r) {
    try {
      return TrackBreak(
        from: DateTime.parse(r['f']! as String),
        to: DateTime.parse(r['to']! as String),
        kind: TrackBreakKind.fromWire(r['brk']! as String),
      );
    } on Object {
      return null;
    }
  }
}

class _Header {
  const _Header(this.dayId, this.pass);

  final int dayId;
  final String pass;
}

/// What a [PointQueue.drain] did.
class DrainResult {
  const DrainResult({
    this.sent = 0,
    this.dropped = 0,
    this.failed = false,
    this.passRefused = false,
  });

  /// Records the server accepted.
  final int sent;

  /// Records dropped because the server refused them for good.
  final int dropped;

  /// A network error stopped the upload; the rest waits for the next try.
  final bool failed;

  /// The server refused the running duty's pass (password reset). The points
  /// were kept until the app gets a new pass.
  final bool passRefused;
}
