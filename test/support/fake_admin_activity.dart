import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/domain/entities/admin_activity_event.dart';
import 'package:diamond_tracking/domain/repositories/admin_activity_repository.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/controllers/admin_dashboard_controller.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Test-only [AdminActivityRepository] that stands in for the server. It lives
/// in test/ so production code never contains a pretend backend.
class FakeAdminActivityRepository implements AdminActivityRepository {
  FakeAdminActivityRepository({List<AdminActivityEvent>? events})
    : events = events ?? <AdminActivityEvent>[];

  List<AdminActivityEvent> events;

  /// Set to make loads fail the way the real repository does.
  AppException? error;

  int fetchCount = 0;

  @override
  Future<List<AdminActivityEvent>> fetchRecent({int limit = 10}) async {
    fetchCount++;
    final failure = error;
    if (failure != null) throw failure;
    return List<AdminActivityEvent>.of(events);
  }
}

/// An activity event for tests, [ago] before now.
AdminActivityEvent activityEvent(
  AdminActivityKind kind, {
  String id = 'a1',
  String name = 'Asha Patil',
  String? code = 'DA-101',
  String? detail,
  Duration ago = const Duration(minutes: 5),
}) {
  return AdminActivityEvent(
    id: id,
    kind: kind,
    occurredAt: DateTime.now().toUtc().subtract(ago),
    personName: name,
    employeeCode: code,
    detail: detail,
  );
}

/// Provider override that feeds the Home activity card from [repository].
Override activityOverride(FakeAdminActivityRepository repository) =>
    adminActivityRepositoryProvider.overrideWithValue(repository);
