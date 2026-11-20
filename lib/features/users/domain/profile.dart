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
    this.hasPhoneSignedIn = false,
  });

  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
    id: row['id'] as String,
    userCode: row['user_code'] as String,
    fullName: row['full_name'] as String,
    phone: row['phone'] as String?,
    contactEmail: row['contact_email'] as String?,
    role: AppRole.fromClaim(row['role']),
    isActive: row['is_active'] as bool? ?? false,
    hasPhoneSignedIn: row['active_device_id'] != null,
  );

  final String id;
  final String userCode;
  final String fullName;
  final String? phone;
  final String? contactEmail;
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
    required this.role,
    this.isActive = true,
  });

  final String userCode;
  final String fullName;
  final String phone;
  final String contactEmail;
  final AppRole role;
  final bool isActive;
}
