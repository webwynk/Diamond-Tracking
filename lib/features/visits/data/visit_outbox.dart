import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../../core/logging/app_log.dart';
import '../../routes/domain/geo_point.dart';

/// A visit kept on the phone until the server has it (M10): saved when there
/// was no internet, sent later.
class PendingVisit {
  const PendingVisit({
    required this.id,
    required this.userId,
    required this.storeName,
    required this.capturedAt,
    this.note,
    this.location,
    this.mocked = false,
    this.accuracyM,
    this.photoId,
  });

  factory PendingVisit.fromJson(Map<String, Object?> json) {
    final num? lat = json['lat'] as num?;
    final num? lng = json['lng'] as num?;
    return PendingVisit(
      id: json['id']! as String,
      userId: json['user']! as String,
      storeName: json['store']! as String,
      note: json['note'] as String?,
      location: lat == null || lng == null
          ? null
          : GeoPoint(lat.toDouble(), lng.toDouble()),
      mocked: json['mocked'] as bool? ?? false,
      accuracyM: (json['acc'] as num?)?.toInt(),
      capturedAt: DateTime.parse(json['at']! as String).toUtc(),
      photoId: json['photo'] as String?,
    );
  }

  /// The file name on the phone (not the server's visit id).
  final String id;

  /// Who took it: only sent while that person is signed in.
  final String userId;
  final String storeName;
  final String? note;

  /// Camera photos only.
  final GeoPoint? location;
  final bool mocked;

  /// How far off the location may be, in metres (L59).
  final int? accuracyM;
  final DateTime capturedAt;

  /// Set once the photo is uploaded, so it is never uploaded twice. Its uuid
  /// is the server's visit id, so sending again never adds a second visit.
  final String? photoId;

  PendingVisit withPhotoId(String photoId) => PendingVisit(
    id: id,
    userId: userId,
    storeName: storeName,
    note: note,
    location: location,
    mocked: mocked,
    accuracyM: accuracyM,
    capturedAt: capturedAt,
    photoId: photoId,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'user': userId,
    'store': storeName,
    'note': note,
    'lat': location?.lat,
    'lng': location?.lng,
    'mocked': mocked,
    'acc': accuracyM,
    'at': capturedAt.toUtc().toIso8601String(),
    'photo': photoId,
  };
}

/// Visits waiting on the phone, in the app's private folder: `<id>.jpg` and
/// `<id>.json` for each.
class VisitOutbox {
  VisitOutbox(this._dir);

  /// The real folder, in the app's private storage.
  factory VisitOutbox.appFolder() => VisitOutbox(() async {
    final Directory support = await getApplicationSupportDirectory();
    return Directory('${support.path}/visit_outbox');
  });

  final Future<Directory> Function() _dir;
  Directory? _resolved;

  Future<Directory> _folder() async {
    final Directory d = _resolved ??= await _dir();
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static final Random _random = Random.secure();

  /// A new file name.
  static String newId() {
    final String rnd = List<String>.generate(
      8,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$rnd';
  }

  /// Keeps a visit and its photo. The details are written last, so a visit is
  /// only listed once its photo is safely on disk.
  Future<void> add(PendingVisit visit, Uint8List jpeg) async {
    final Directory d = await _folder();
    File('${d.path}/${visit.id}.jpg').writeAsBytesSync(jpeg, flush: true);
    _writeJson(d, visit);
  }

  /// Saves a change (the photo id after the upload).
  Future<void> update(PendingVisit visit) async =>
      _writeJson(await _folder(), visit);

  void _writeJson(Directory d, PendingVisit visit) {
    final File tmp = File('${d.path}/${visit.id}.json.tmp')
      ..writeAsStringSync(jsonEncode(visit.toJson()), flush: true);
    tmp.renameSync('${d.path}/${visit.id}.json');
  }

  Future<Uint8List> photo(PendingVisit visit) async =>
      File('${(await _folder()).path}/${visit.id}.jpg').readAsBytesSync();

  Future<void> remove(PendingVisit visit) async {
    final Directory d = await _folder();
    for (final String ext in <String>['json', 'jpg']) {
      final File f = File('${d.path}/${visit.id}.$ext');
      if (f.existsSync()) f.deleteSync();
    }
  }

  /// Waiting visits, oldest first. Only [userId]'s when given.
  Future<List<PendingVisit>> pending({String? userId}) async {
    final Directory d = await _folder();
    final List<PendingVisit> out = <PendingVisit>[];
    for (final FileSystemEntity f in d.listSync()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final PendingVisit v = PendingVisit.fromJson(
          (jsonDecode(f.readAsStringSync()) as Map<Object?, Object?>)
              .cast<String, Object?>(),
        );
        if (userId == null || v.userId == userId) out.add(v);
      } on Object catch (e) {
        AppLog.failure('VisitOutbox.pending', e);
      }
    }
    out.sort(
      (PendingVisit a, PendingVisit b) => a.capturedAt.compareTo(b.capturedAt),
    );
    return out;
  }

  /// Everything, after logging out.
  Future<void> clear() async {
    final Directory d = await _folder();
    d.deleteSync(recursive: true);
  }
}
