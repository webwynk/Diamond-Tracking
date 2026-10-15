import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../domain/entities/user_profile.dart';
import 'admin_employee_form_state.dart';
import 'admin_employee_list_controller.dart';
import 'admin_employee_list_state.dart';

/// Global provider for managing the employee creation and edition flow.
final adminEmployeeFormControllerProvider =
    NotifierProvider<AdminEmployeeFormNotifier, AdminEmployeeFormState>(
  AdminEmployeeFormNotifier.new,
);

/// Controller governing field inputs, PIN generation, validation, and submission.
class AdminEmployeeFormNotifier extends Notifier<AdminEmployeeFormState> {
  final Random _random = Random();

  @override
  AdminEmployeeFormState build() {
    return const AdminEmployeeFormState(
      fullName: 'Kiran Deshmukh',
      phoneNumber: '+91 98220 11334',
      email: 'kiran.d@diamondagritech.in',
      employeeCode: 'DA-144',
      initialPin: '849201',
      role: UserRole.employee,
      isEmployeeCodeAvailable: true,
    );
  }

  /// Initializes the form with an existing employee for editing or defaults for creating.
  void initForm({AdminEmployeeItem? employee}) {
    if (employee != null) {
      state = AdminEmployeeFormState(
        fullName: employee.name,
        phoneNumber: employee.phoneNumber,
        email: employee.email ??
            '${employee.name.toLowerCase().replaceAll(' ', '.')}@diamondagritech.in',
        employeeCode: employee.employeeCode,
        initialPin: '******',
        role: employee.role,
        isEditMode: true,
        existingEmployeeId: employee.id,
        isEmployeeCodeAvailable: true,
      );
    } else {
      state = const AdminEmployeeFormState(
        fullName: 'Kiran Deshmukh',
        phoneNumber: '+91 98220 11334',
        email: 'kiran.d@diamondagritech.in',
        employeeCode: 'DA-144',
        initialPin: '849201',
        role: UserRole.employee,
        isEmployeeCodeAvailable: true,
      );
    }
  }

  void setFullName(String value) {
    state = state.copyWith(fullName: value);
  }

  void setPhoneNumber(String value) {
    state = state.copyWith(phoneNumber: value);
  }

  void setEmail(String value) {
    state = state.copyWith(email: value);
  }

  void setEmployeeCode(String value) {
    final code = value.trim().toUpperCase();
    state = state.copyWith(
      employeeCode: code,
      isEmployeeCodeAvailable: code.isNotEmpty,
    );
  }

  void setRole(UserRole role) {
    state = state.copyWith(role: role);
  }

  /// Generates a random 6-digit numeric PIN for the employee.
  void regeneratePin() {
    final randomPin = (100000 + _random.nextInt(900000)).toString();
    state = state.copyWith(initialPin: randomPin);
  }

  /// Submits the employee creation or modification.
  Future<bool> submit() async {
    if (!state.isValid) return false;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      // Simulate provisioning delay (matching HTML design reference)
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final rosterNotifier = ref.read(adminEmployeeListControllerProvider.notifier);

      if (state.isEditMode && state.existingEmployeeId != null) {
        final updated = AdminEmployeeItem(
          id: state.existingEmployeeId!,
          name: state.fullName.trim(),
          employeeCode: state.employeeCode.trim(),
          phoneNumber: state.phoneNumber.trim(),
          email: state.email.trim(),
          role: state.role,
          status: AdminEmployeeStatus.offDuty,
        );
        rosterNotifier.updateEmployee(updated);
      } else {
        final newEmployee = AdminEmployeeItem(
          id: 'emp-${DateTime.now().millisecondsSinceEpoch}',
          name: state.fullName.trim(),
          employeeCode: state.employeeCode.trim(),
          phoneNumber: state.phoneNumber.trim(),
          email: state.email.trim(),
          role: state.role,
          status: AdminEmployeeStatus.offDuty,
        );
        rosterNotifier.addEmployee(newEmployee);
      }

      state = state.copyWith(isSaving: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to provision employee: $e',
      );
      return false;
    }
  }
}
