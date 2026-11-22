import 'package:flutter/widgets.dart' show StringCharacters;

import '../../auth/domain/auth_status.dart';

/// A user as the admin manages it.
class Profile {
  const Profile({
    required this.id,
    required this.userCode,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.phone,
    this.contactEmail,
    this.designation,
    this.hasPhoneSignedIn = false,
  });

  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
    id: row['id'] as String,
    userCode: row['user_code'] as String,
    fullName: row['full_name'] as String,
    phone: row['phone'] as String?,
    contactEmail: row['contact_email'] as String?,
    designation: row['designation'] as String?,
    role: AppRole.fromClaim(row['role']),
    isActive: row['is_active'] as bool? ?? false,
    hasPhoneSignedIn: row['active_device_id'] != null,
  );

  final String id;
  final String userCode;
  final String fullName;
  final String? phone;
  final String? contactEmail;

  /// The job title the admin chose, or null while none is set.
  final String? designation;
  final AppRole role;
  final bool isActive;

  /// True while a phone holds this account (one phone at a time).
  final bool hasPhoneSignedIn;
}

/// What the admin fills in to create or edit a user.
class ProfileDraft {
  const ProfileDraft({
    required this.userCode,
    required this.fullName,
    required this.phone,
    required this.contactEmail,
    required this.designation,
    required this.role,
    this.isActive = true,
  });

  final String userCode;
  final String fullName;
  final String phone;
  final String contactEmail;

  /// Empty when none is chosen.
  final String designation;
  final AppRole role;
  final bool isActive;
}

/// "RD" for "Rahul Das", "R" for "Rahul".
String initialsOf(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  final String first = parts.first.characters.first;
  if (parts.length == 1) return first.toUpperCase();
  return (first + parts.last.characters.first).toUpperCase();
}
