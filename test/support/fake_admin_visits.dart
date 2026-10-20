import 'dart:async';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/domain/entities/visit_page.dart';
import 'package:diamond_tracking/domain/entities/visit_record.dart';
import 'package:diamond_tracking/domain/repositories/admin_visit_repository.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/controllers/admin_visits_controller.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// A visit as the admin reads it from the server.
VisitRecord adminVisit(
  String id, {
  int minute = 0,
  String? storeName = 'Kisan Kendra',
  String? note,
  String? photoPublicId,
  DateTime? photoRemovedAt,
}) => VisitRecord(
  id: id,
  sessionId: 'session-1',
  employeeId: 'emp-1',
  storeName: storeName,
  note: note,
  latitude: 19.9975,
  longitude: 73.7898,
  accuracy: 4.2,
  capturedAt: DateTime.utc(2026, 10, 18, 4, minute),
  photoPublicId: photoPublicId,
  photoRemovedAt: photoRemovedAt,
);

/// Pages over a fixed list, newest first, and records what was asked.
class FakeAdminVisitRepository implements AdminVisitRepository {
  FakeAdminVisitRepository(this.all);

  /// Newest first.
  List<VisitRecord> all;

  /// Throws this instead of answering while set.
  AppException? failure;

  /// When set, a request waits for it before answering.
  Completer<void>? gate;

  final List<({String employeeId, String? afterId, int limit})> calls =
      <({String employeeId, String? afterId, int limit})>[];

  @override
  Future<VisitPage> fetchPage({
    required String employeeId,
    VisitRecord? after,
    int limit = 20,
  }) async {
    calls.add((employeeId: employeeId, afterId: after?.id, limit: limit));
    await gate?.future;
    final error = failure;
    if (error != null) throw error;
    final start = after == null
        ? 0
        : all.indexWhere((v) => v.id == after.id) + 1;
    final rest = all.skip(start).toList();
    return VisitPage(
      visits: rest.take(limit).toList(),
      hasMore: rest.length > limit,
    );
  }
}

/// Routes the admin's Visits list to [repository] (an empty one by default), so
/// a test that opens an employee profile never reaches a real server client.
Override adminVisitsOverride([FakeAdminVisitRepository? repository]) =>
    adminVisitRepositoryProvider.overrideWithValue(
      repository ?? FakeAdminVisitRepository(<VisitRecord>[]),
    );
