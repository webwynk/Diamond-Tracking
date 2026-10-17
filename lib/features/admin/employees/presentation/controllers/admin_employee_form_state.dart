import 'package:flutter/foundation.dart';

import '../../../../../domain/entities/user_profile.dart';
import '../../../../auth/domain/pin_validator.dart';

/// State representation for Screen 19 (Create / Edit Employee — Admin).
@immutable
class AdminEmployeeFormState {
  const AdminEmployeeFormState({
    this.fullName = '',
    this.phoneNumber = '',
    this.email = '',
    this.employeeCode = '',
    this.initialPin = '',
    this.role = UserRole.employee,
    this.isEmployeeCodeAvailable = true,
    this.isSaving = false,
    this.isSuccess = false,
    this.errorMessage,
    this.isEditMode = false,
    this.existingEmployeeId,
  });

  final String fullName;
  final String phoneNumber;
  final String email;
  final String employeeCode;
  final String initialPin;
  final UserRole role;
  final bool isEmployeeCodeAvailable;
  final bool isSaving;
  final bool isSuccess;
  final String? errorMessage;
  final bool isEditMode;
  final String? existingEmployeeId;

  // These mirror what the create-employee function checks, so the form never
  // offers a Save the server is certain to refuse.
  static final RegExp _codePattern = RegExp(r'^[A-Z]{2,4}-\d{2,6}$');
  static final RegExp _phonePattern = RegExp(r'^\+?\d{10,15}$');
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  bool get isNameValid {
    final length = fullName.trim().length;
    return length >= 2 && length <= 80;
  }

  bool get isPhoneValid =>
      _phonePattern.hasMatch(phoneNumber.replaceAll(RegExp(r'[\s-]'), ''));

  /// The contact email is optional (PRD F2); when given it must look like one.
  bool get isEmailValid =>
      email.trim().isEmpty || _emailPattern.hasMatch(email.trim());

  /// Like DA-144: 2-4 capital letters, a dash, 2-6 digits.
  bool get isEmployeeCodeValid =>
      _codePattern.hasMatch(employeeCode.trim().toUpperCase());

  /// Six digits, not one repeated digit, not a simple run (PRD F1).
  bool get isPinValid =>
      PinValidator.hasSixDigits(initialPin) &&
      PinValidator.isNotRepeated(initialPin) &&
      PinValidator.isNotSequential(initialPin);

  /// What is wrong with the employee ID, once something has been typed.
  String? get employeeCodeError =>
      isEditMode || employeeCode.isEmpty || isEmployeeCodeValid
      ? null
      : 'Use a code like DA-144: 2-4 letters, a dash, then 2-6 digits.';

  /// What is wrong with the PIN, once something has been typed.
  String? get pinError {
    if (isEditMode || initialPin.isEmpty || isPinValid) return null;
    if (!PinValidator.hasSixDigits(initialPin)) {
      return 'The PIN must be 6 digits.';
    }
    if (!PinValidator.isNotRepeated(initialPin)) {
      return 'The PIN cannot be one repeated digit, like 111111.';
    }
    return 'The PIN cannot be a simple run, like 123456.';
  }

  /// Full form validity gate. Editing changes only name, phone and email; the
  /// ID and PIN are fixed at creation.
  bool get isValid =>
      isNameValid &&
      isPhoneValid &&
      isEmailValid &&
      (isEditMode || (isEmployeeCodeValid && isPinValid)) &&
      isEmployeeCodeAvailable &&
      !isSaving;

  AdminEmployeeFormState copyWith({
    String? fullName,
    String? phoneNumber,
    String? email,
    String? employeeCode,
    String? initialPin,
    UserRole? role,
    bool? isEmployeeCodeAvailable,
    bool? isSaving,
    bool? isSuccess,
    String? errorMessage,
    bool? isEditMode,
    String? existingEmployeeId,
  }) {
    return AdminEmployeeFormState(
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      employeeCode: employeeCode ?? this.employeeCode,
      initialPin: initialPin ?? this.initialPin,
      role: role ?? this.role,
      isEmployeeCodeAvailable:
          isEmployeeCodeAvailable ?? this.isEmployeeCodeAvailable,
      isSaving: isSaving ?? this.isSaving,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
      isEditMode: isEditMode ?? this.isEditMode,
      existingEmployeeId: existingEmployeeId ?? this.existingEmployeeId,
    );
  }
}
