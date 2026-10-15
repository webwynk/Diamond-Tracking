import 'package:flutter/foundation.dart';

import '../../../../../domain/entities/user_profile.dart';

/// State representation for Screen 19 (Create / Edit Employee — Admin).
@immutable
class AdminEmployeeFormState {
  const AdminEmployeeFormState({
    this.fullName = '',
    this.phoneNumber = '',
    this.email = '',
    this.employeeCode = 'DA-144',
    this.initialPin = '849201',
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

  bool get isNameValid => fullName.trim().length >= 2;
  bool get isPhoneValid => phoneNumber.trim().length >= 10;
  bool get isEmailValid =>
      email.trim().contains('@') && email.trim().contains('.');
  bool get isEmployeeCodeValid => employeeCode.trim().isNotEmpty;
  bool get isPinValid => initialPin.trim().length == 6;

  /// Full form validity gate.
  bool get isValid =>
      isNameValid &&
      isPhoneValid &&
      isEmailValid &&
      isEmployeeCodeValid &&
      isPinValid &&
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
