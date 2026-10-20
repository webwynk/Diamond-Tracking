import '../../features/admin/employees/presentation/controllers/admin_employee_list_state.dart';

/// Contract for employee roster management and provisioning operations.
///
/// Implemented by [SupabaseEmployeeRepository] in the data layer. Every method
/// either returns real server data or throws an `AppException`; none of them
/// invent a result when the backend cannot be reached.
abstract class EmployeeRepository {
  /// Fetches every employee (not admins), newest first.
  ///
  /// Search and filter chips are applied on the device by the list state, so
  /// they always agree with what is on screen.
  ///
  /// Throws [NetworkException] when offline, [UnauthorizedRoleException] when
  /// the caller may not read the roster, or [ServerException] otherwise.
  Future<List<AdminEmployeeItem>> getEmployees();

  /// Provisions a new employee login and profile via the `create-employee` Edge Function.
  ///
  /// Throws [ValidationException] if validation fails,
  /// [ConflictException] if employee code or phone is already taken,
  /// [UnauthorizedRoleException] if caller is not an active admin,
  /// [NetworkException] when offline, or [ServerException] on failure.
  Future<AdminEmployeeItem> createEmployee({
    required String fullName,
    required String phone,
    required String employeeCode,
    required String pin,
    String? email,
  });

  /// Updates an existing employee's editable attributes (name, phone, contact email).
  ///
  /// Employee code and role are immutable per PRD F2 and enforced by the
  /// database; the returned item carries no duty status (the caller keeps it).
  Future<AdminEmployeeItem> updateEmployee({
    required String id,
    required String fullName,
    required String phone,
    String? email,
  });

  /// Blocks an employee with a stated reason. The database stamps who and when
  /// and writes the audit log entry.
  ///
  /// Throws if the server changed nothing (for example the caller is not an
  /// admin), so a failed block is never reported as done.
  Future<void> blockEmployee({required String id, required String reason});

  /// Restores a blocked employee to active status.
  Future<void> unblockEmployee({required String id});

  /// Gives an employee a new temporary PIN (admin only, through the
  /// `employee-auth` Edge Function). The employee must change it at the next
  /// sign-in and any lockout is cleared. The server applies the PIN rules and
  /// writes the audit entry in the same step.
  ///
  /// Throws [ValidationException] for a PIN the rules refuse,
  /// [UnauthorizedRoleException] if the caller is not an active admin,
  /// [NetworkException] when offline, or [ServerException] otherwise.
  Future<void> resetPin({required String id, required String newPin});

  /// Clears the phone registered to an employee (BR-13) through the audited
  /// `admin_clear_device` database function. It also signs the employee out of
  /// their current phone; the next phone they sign in on becomes the registered
  /// one.
  ///
  /// Returns true when a phone was registered and is now cleared, false when
  /// none was registered (nothing changed, nothing logged).
  ///
  /// Throws [UnauthorizedRoleException] if the caller is not an active admin,
  /// [ValidationException] if the employee no longer exists,
  /// [NetworkException] when offline, or [ServerException] otherwise.
  Future<bool> clearDevice({required String id});
}
