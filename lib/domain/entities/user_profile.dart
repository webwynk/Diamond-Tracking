import 'package:flutter/foundation.dart';

/// User roles in Diamond Agritech Tracking App.
enum UserRole {
  admin('admin'),
  employee('employee');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String val) {
    return val.toLowerCase() == 'admin' ? UserRole.admin : UserRole.employee;
  }
}

/// User account status.
enum UserStatus {
  active('active'),
  blocked('blocked');

  const UserStatus(this.value);
  final String value;

  static UserStatus fromString(String val) {
    return val.toLowerCase() == 'blocked' ? UserStatus.blocked : UserStatus.active;
  }
}

/// Domain entity representing a user profile from the `public.profiles` table.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.role,
    required this.status,
    required this.fullName,
    required this.mustChangePin,
    required this.failedLoginAttempts,
    required this.createdAt,
    required this.updatedAt,
    this.employeeCode,
    this.phone,
    this.email,
    this.deviceId,
    this.lockedUntil,
    this.blockedAt,
    this.blockedReason,
    this.blockedBy,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      role: UserRole.fromString(json['role'] as String? ?? 'employee'),
      status: UserStatus.fromString(json['status'] as String? ?? 'active'),
      fullName: json['full_name'] as String? ?? '',
      mustChangePin: json['must_change_pin'] as bool? ?? true,
      failedLoginAttempts: json['failed_login_attempts'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      employeeCode: json['employee_code'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      deviceId: json['device_id'] as String?,
      lockedUntil: json['locked_until'] != null
          ? DateTime.tryParse(json['locked_until'] as String)
          : null,
      blockedAt: json['blocked_at'] != null
          ? DateTime.tryParse(json['blocked_at'] as String)
          : null,
      blockedReason: json['blocked_reason'] as String?,
      blockedBy: json['blocked_by'] as String?,
    );
  }

  final String id;
  final UserRole role;
  final UserStatus status;
  final String fullName;
  final bool mustChangePin;
  final int failedLoginAttempts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? employeeCode;
  final String? phone;
  final String? email;
  final String? deviceId;
  final DateTime? lockedUntil;
  final DateTime? blockedAt;
  final String? blockedReason;
  final String? blockedBy;

  bool get isAdmin => role == UserRole.admin;
  bool get isEmployee => role == UserRole.employee;
  bool get isActive => status == UserStatus.active;
  bool get isBlocked => status == UserStatus.blocked;

  /// Check whether the account is currently rate-limited/locked.
  bool isLocked([DateTime? now]) {
    final DateTime current = now ?? DateTime.now();
    return lockedUntil != null && lockedUntil!.isAfter(current);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'role': role.value,
      'status': status.value,
      'full_name': fullName,
      'must_change_pin': mustChangePin,
      'failed_login_attempts': failedLoginAttempts,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'employee_code': employeeCode,
      'phone': phone,
      'email': email,
      'device_id': deviceId,
      'locked_until': lockedUntil?.toIso8601String(),
      'blocked_at': blockedAt?.toIso8601String(),
      'blocked_reason': blockedReason,
      'blocked_by': blockedBy,
    };
  }

  UserProfile copyWith({
    String? id,
    UserRole? role,
    UserStatus? status,
    String? fullName,
    bool? mustChangePin,
    int? failedLoginAttempts,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? employeeCode,
    String? phone,
    String? email,
    String? deviceId,
    DateTime? lockedUntil,
    DateTime? blockedAt,
    String? blockedReason,
    String? blockedBy,
  }) {
    return UserProfile(
      id: id ?? this.id,
      role: role ?? this.role,
      status: status ?? this.status,
      fullName: fullName ?? this.fullName,
      mustChangePin: mustChangePin ?? this.mustChangePin,
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      employeeCode: employeeCode ?? this.employeeCode,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      deviceId: deviceId ?? this.deviceId,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      blockedAt: blockedAt ?? this.blockedAt,
      blockedReason: blockedReason ?? this.blockedReason,
      blockedBy: blockedBy ?? this.blockedBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          role == other.role &&
          status == other.status &&
          employeeCode == other.employeeCode &&
          deviceId == other.deviceId;

  @override
  int get hashCode =>
      id.hashCode ^
      role.hashCode ^
      status.hashCode ^
      employeeCode.hashCode ^
      deviceId.hashCode;
}
