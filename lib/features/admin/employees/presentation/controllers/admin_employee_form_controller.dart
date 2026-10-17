import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/app_exceptions.dart';
import '../../../../../domain/entities/user_profile.dart';
import '../../../../auth/domain/pin_validator.dart';
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
  final Random _random = Random.secure();

  @override
  AdminEmployeeFormState build() => const AdminEmployeeFormState();

  /// Initializes the form with an existing employee for editing, or blank
  /// fields and a freshly generated PIN for creating.
  void initForm({AdminEmployeeItem? employee}) {
    if (employee != null) {
      state = AdminEmployeeFormState(
        fullName: employee.name,
        phoneNumber: employee.phoneNumber,
        email: employee.email ?? '',
        employeeCode: employee.employeeCode,
        initialPin: '******',
        role: employee.role,
        isEditMode: true,
        existingEmployeeId: employee.id,
        isEmployeeCodeAvailable: true,
      );
    } else {
      state = AdminEmployeeFormState(initialPin: _generatePin());
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

  /// Keeps the PIN the admin typed: digits only, at most 6.
  void setPin(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    state = state.copyWith(
      initialPin: digits.length > 6 ? digits.substring(0, 6) : digits,
    );
  }

  /// Generates a random 6-digit numeric PIN for the employee.
  void regeneratePin() {
    state = state.copyWith(initialPin: _generatePin());
  }

  /// A random 6-digit PIN that obeys the PIN rules (PRD F1): not one repeated
  /// digit, not a simple sequence.
  String _generatePin() {
    while (true) {
      final pin = (100000 + _random.nextInt(900000)).toString();
      if (PinValidator.isNotRepeated(pin) &&
          PinValidator.isNotSequential(pin)) {
        return pin;
      }
    }
  }

  /// Submits the employee creation or modification.
  Future<bool> submit() async {
    if (!state.isValid) return false;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final repo = ref.read(employeeRepositoryProvider);
      final rosterNotifier = ref.read(
        adminEmployeeListControllerProvider.notifier,
      );

      if (state.isEditMode && state.existingEmployeeId != null) {
        final updated = await repo.updateEmployee(
          id: state.existingEmployeeId!,
          fullName: state.fullName.trim(),
          phone: state.phoneNumber.trim(),
          email: state.email.trim().isEmpty ? null : state.email.trim(),
        );
        rosterNotifier.updateEmployee(updated);
      } else {
        final created = await repo.createEmployee(
          fullName: state.fullName.trim(),
          phone: state.phoneNumber.trim(),
          employeeCode: state.employeeCode.trim().toUpperCase(),
          pin: state.initialPin.trim(),
          email: state.email.trim().isEmpty ? null : state.email.trim(),
        );
        rosterNotifier.addEmployee(created);
      }

      state = state.copyWith(isSaving: false, isSuccess: true);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Could not save the employee. Please try again.',
      );
      return false;
    }
  }
}
