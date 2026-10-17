import 'dart:async';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/utils/phone_clock.dart';
import 'package:diamond_tracking/domain/entities/live_position.dart';
import 'package:diamond_tracking/domain/repositories/live_location_repository.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_controller.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/map/presentation/controllers/admin_live_map_controller.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'fake_employee_repository.dart';

/// Test-only [LiveLocationRepository] that stands in for the server. It lives
/// in test/ so production code never contains a pretend backend.
///
/// [positions] is what a full load returns; [emit] pushes a Realtime change.
class FakeLiveLocationRepository implements LiveLocationRepository {
  FakeLiveLocationRepository({List<LivePosition>? positions, this.serverTime})
    : positions = positions ?? <LivePosition>[];

  List<LivePosition> positions;

  /// What the server clock says; null means the real clock.
  DateTime? serverTime;

  /// Set to make full loads fail the way the real repository does.
  AppException? error;

  int fetchCount = 0;

  final StreamController<LiveLocationEvent> _events =
      StreamController<LiveLocationEvent>.broadcast(sync: true);

  /// Whether anyone is listening to the change stream right now.
  bool get hasListener => _events.hasListener;

  void emit(LiveLocationEvent event) => _events.add(event);

  @override
  Future<List<LivePosition>> fetchAll() async {
    fetchCount++;
    final failure = error;
    if (failure != null) throw failure;
    return List<LivePosition>.of(positions);
  }

  @override
  Future<DateTime> getServerTime() async =>
      serverTime ?? DateTime.now().toUtc();

  @override
  Stream<LiveLocationEvent> watch() {
    return _events.stream;
  }
}

/// A position for tests, [ago] before now.
LivePosition livePosition(
  String employeeId, {
  Duration ago = const Duration(seconds: 20),
  double latitude = 19.99,
  double longitude = 73.79,
  bool isMock = false,
  int? battery = 80,
  DateTime? now,
}) {
  return LivePosition(
    employeeId: employeeId,
    sessionId: 'session-$employeeId',
    latitude: latitude,
    longitude: longitude,
    accuracy: 6,
    batteryLevel: battery,
    isMock: isMock,
    recordedAt: (now ?? DateTime.now().toUtc()).subtract(ago),
  );
}

/// A roster entry for tests.
AdminEmployeeItem rosterEmployee(String id, String name, String code) {
  return AdminEmployeeItem(
    id: id,
    name: name,
    employeeCode: code,
    phoneNumber:
        '+9198200${code.replaceAll(RegExp(r'\D'), '').padLeft(5, '0')}',
    status: AdminEmployeeStatus.onDuty,
  );
}

/// Provider overrides that feed the live map from fakes.
List<Override> liveMapOverrides(
  FakeLiveLocationRepository live,
  FakeEmployeeRepository roster, {
  DateTime Function()? clock,
}) {
  return <Override>[
    if (clock != null) phoneClockProvider.overrideWithValue(clock),
    liveLocationRepositoryProvider.overrideWithValue(live),
    employeeRepositoryProvider.overrideWithValue(roster),
  ];
}
