import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/domain/repositories/employee_repository.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_controller.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Test-only [EmployeeRepository] that stands in for the server. It lives in
/// test/ so production code never contains a pretend backend.
///
/// Set [error] to make every call fail the way the real repository does.
class FakeEmployeeRepository implements EmployeeRepository {
  FakeEmployeeRepository({
    List<AdminEmployeeItem>? roster,
    this.error,
    this.createDelay = Duration.zero,
  }) : roster = roster ?? <AdminEmployeeItem>[];

  List<AdminEmployeeItem> roster;
  AppException? error;

  /// How long [createEmployee] takes, so tests can observe the saving state.
  final Duration createDelay;

  /// Names of the calls received, in order, for assertions.
  final List<String> calls = <String>[];

  void _record(String call) {
    calls.add(call);
    final failure = error;
    if (failure != null) throw failure;
  }

  @override
  Future<List<AdminEmployeeItem>> getEmployees() async {
    _record('getEmployees');
    return List<AdminEmployeeItem>.of(roster);
  }

  @override
  Future<AdminEmployeeItem> createEmployee({
    required String fullName,
    required String phone,
    required String employeeCode,
    required String pin,
    String? email,
  }) async {
    _record('createEmployee');
    await Future<void>.delayed(createDelay);
    return AdminEmployeeItem(
      id: 'new-${calls.length}',
      name: fullName.trim(),
      employeeCode: employeeCode.trim().toUpperCase(),
      phoneNumber: phone.trim(),
      status: AdminEmployeeStatus.offDuty,
      email: email,
    );
  }

  @override
  Future<AdminEmployeeItem> updateEmployee({
    required String id,
    required String fullName,
    required String phone,
    String? email,
  }) async {
    _record('updateEmployee');
    return AdminEmployeeItem(
      id: id,
      name: fullName.trim(),
      employeeCode: '',
      phoneNumber: phone.trim(),
      status: AdminEmployeeStatus.offDuty,
      email: email,
    );
  }

  @override
  Future<void> blockEmployee({
    required String id,
    required String reason,
  }) async {
    _record('blockEmployee');
  }

  @override
  Future<void> unblockEmployee({required String id}) async {
    _record('unblockEmployee');
  }

  /// The PINs set through [resetPin], by employee id.
  final Map<String, String> pinsReset = <String, String>{};

  @override
  Future<void> resetPin({required String id, required String newPin}) async {
    _record('resetPin');
    pinsReset[id] = newPin;
  }

  /// The employee ids whose phone [clearDevice] cleared.
  final List<String> devicesCleared = <String>[];

  /// What [clearDevice] answers: true = a phone was registered and is cleared.
  bool clearDeviceResult = true;

  @override
  Future<bool> clearDevice({required String id}) async {
    _record('clearDevice');
    devicesCleared.add(id);
    return clearDeviceResult;
  }
}

/// Provider override that routes the roster and form to [repository].
Override fakeEmployeeRepositoryOverride([FakeEmployeeRepository? repository]) =>
    employeeRepositoryProvider.overrideWithValue(
      repository ?? FakeEmployeeRepository(),
    );
