import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import '../network_failure.dart';

/// Supabase implementation of [EmployeeRepository].
///
/// Reads `public.profiles` and `public.live_locations`, and invokes the
/// `create-employee` Edge Function for server-side employee provisioning
/// (the secret key needed to create a login never reaches the app).
///
/// Failures are translated into `AppException`s; nothing is faked when the
/// backend cannot be reached.
class SupabaseEmployeeRepository implements EmployeeRepository {
  SupabaseEmployeeRepository([SupabaseClient? client]) : _injected = client;

  final SupabaseClient? _injected;

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  @override
  Future<List<AdminEmployeeItem>> getEmployees() {
    return _run('load the team', () async {
      final profileRows = await _client
          .from('profiles')
          .select()
          .eq('role', 'employee')
          // Tie-broken ordering per docs/06 section 6.
          .order('created_at', ascending: false)
          .order('id', ascending: false);

      // One live_locations row exists exactly while an employee is on duty.
      final liveRows = await _client
          .from('live_locations')
          .select('employee_id');
      final onDutyIds = <String>{
        for (final row in liveRows) row['employee_id'] as String,
      };

      return <AdminEmployeeItem>[
        for (final raw in profileRows)
          _toItem(UserProfile.fromJson(raw), onDutyIds),
      ];
    });
  }

  @override
  Future<AdminEmployeeItem> createEmployee({
    required String fullName,
    required String phone,
    required String employeeCode,
    required String pin,
    String? email,
  }) {
    return _run('create the employee', () async {
      final response = await _client.functions.invoke(
        'create-employee',
        body: <String, dynamic>{
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'employee_code': employeeCode.trim().toUpperCase(),
          'pin': pin.trim(),
          'email': email?.trim() ?? '',
        },
      );

      // A non-2xx answer never gets here: the client throws FunctionException,
      // handled in [_translate].
      final data = response.data;
      final employee = data is Map ? data['employee'] : null;
      final id = employee is Map ? employee['id'] : null;
      if (employee is! Map || id is! String || id.isEmpty) {
        throw const ServerException(
          'The server did not confirm the new employee. Check the Team list before retrying.',
        );
      }
      return AdminEmployeeItem(
        id: id,
        name: employee['full_name'] as String? ?? fullName.trim(),
        employeeCode:
            employee['employee_code'] as String? ??
            employeeCode.trim().toUpperCase(),
        phoneNumber: employee['phone'] as String? ?? phone.trim(),
        status: AdminEmployeeStatus.offDuty,
        email: employee['contact_email'] as String?,
      );
    });
  }

  @override
  Future<AdminEmployeeItem> updateEmployee({
    required String id,
    required String fullName,
    required String phone,
    String? email,
  }) {
    return _run('update the employee', () async {
      final trimmedEmail = email?.trim() ?? '';
      final row = await _client
          .from('profiles')
          .update(<String, dynamic>{
            'full_name': fullName.trim(),
            'phone': phone.trim(),
            'contact_email': trimmedEmail.isEmpty ? null : trimmedEmail,
          })
          .eq('id', id)
          .eq('role', 'employee')
          .select()
          .single();
      return _toItem(UserProfile.fromJson(row), const <String>{});
    });
  }

  @override
  Future<void> blockEmployee({required String id, required String reason}) {
    return _setBlocked(id, <String, dynamic>{
      'status': 'blocked',
      'blocked_reason': reason.trim(),
    }, 'block the employee');
  }

  @override
  Future<void> unblockEmployee({required String id}) {
    return _setBlocked(id, <String, dynamic>{
      'status': 'active',
    }, 'unblock the employee');
  }

  Future<void> _setBlocked(
    String id,
    Map<String, dynamic> values,
    String action,
  ) {
    return _run(action, () async {
      final changed = await _client
          .from('profiles')
          .update(values)
          .eq('id', id)
          .eq('role', 'employee')
          .select('id');
      // Row-level security hides rows the caller may not change: zero rows
      // means nothing happened, which must not be shown as success.
      if (changed.isEmpty) {
        throw const UnauthorizedRoleException(
          'The change was not applied. Only active administrators can do this.',
        );
      }
    });
  }

  AdminEmployeeItem _toItem(UserProfile profile, Set<String> onDutyIds) {
    final isBlocked = profile.status == UserStatus.blocked;
    return AdminEmployeeItem(
      id: profile.id,
      name: profile.fullName,
      employeeCode: profile.employeeCode ?? '',
      phoneNumber: profile.phone ?? '',
      status: isBlocked
          ? AdminEmployeeStatus.blocked
          : onDutyIds.contains(profile.id)
          ? AdminEmployeeStatus.onDuty
          : AdminEmployeeStatus.offDuty,
      isActive: !isBlocked,
      email: profile.contactEmail,
      role: profile.role,
    );
  }

  Future<T> _run<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on FunctionException catch (e) {
      throw _translateFunction(e, action);
    } on PostgrestException catch (e) {
      throw _translatePostgrest(e, action);
    } catch (e, st) {
      final network = asNetworkFailure(e);
      if (network != null) throw network;
      debugPrint('EmployeeRepository: could not $action: $e\n$st');
      // Includes "Supabase not initialised". Raw text is never shown to the
      // admin; the cause is in the debug console.
      throw ServerException('Could not $action. Please try again.');
    }
  }

  AppException _translateFunction(FunctionException e, String action) {
    final details = e.details;
    final code = details is Map ? details['error'] : null;
    final fields = details is Map ? details['fields'] : null;

    switch (e.status) {
      case 0:
        return const NetworkException();
      case 400:
        if (fields is Map && fields.isNotEmpty) {
          return ValidationException(fields.values.join('. '));
        }
        return const ValidationException(
          'Please check the employee details and try again.',
        );
      case 401:
        return const UnauthorizedRoleException(
          'Your session has expired. Sign in again.',
        );
      case 403:
        return const UnauthorizedRoleException(
          'Only active administrators can create employees.',
        );
      case 409:
        if (code == 'employee_code_taken') {
          return const ConflictException(
            'That employee code is already in use.',
          );
        }
        if (code == 'phone_taken') {
          return const ConflictException(
            'That phone number already belongs to another employee.',
          );
        }
        return const ConflictException(
          'An employee with this code or phone number already exists.',
        );
      default:
        return ServerException('Could not $action. Please try again.');
    }
  }

  AppException _translatePostgrest(PostgrestException e, String action) {
    if (e.code == 'P0001' && e.message.contains('immutable_field')) {
      return const ValidationException(
        'Employee code and role cannot be changed.',
      );
    }
    if (e.code == '23505') {
      return const ConflictException(
        'That phone number already belongs to another employee.',
      );
    }
    if (e.code == '42501') {
      return const UnauthorizedRoleException(
        'Only active administrators can do this.',
      );
    }
    return ServerException('Could not $action. Please try again.');
  }
}
