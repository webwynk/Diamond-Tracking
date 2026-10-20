import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile entity', () {
    final Map<String, dynamic> sampleEmployeeJson = <String, dynamic>{
      'id': '11111111-1111-1111-1111-111111111111',
      'role': 'employee',
      'status': 'active',
      'employee_code': 'DA-014',
      'full_name': 'Suresh Patel',
      'phone': '+919876543210',
      'email': 'da-014@diamondagritech.internal',
      'device_id': 'android-device-abc-123',
      'must_change_pin': true,
      'failed_login_attempts': 0,
      'locked_until': null,
      'blocked_at': null,
      'blocked_reason': null,
      'blocked_by': null,
      'created_at': '2026-10-15T10:00:00.000Z',
      'updated_at': '2026-10-15T10:00:00.000Z',
    };

    final Map<String, dynamic> sampleAdminJson = <String, dynamic>{
      'id': '22222222-2222-2222-2222-222222222222',
      'role': 'admin',
      'status': 'active',
      'employee_code': null,
      'full_name': 'Operations Admin',
      'phone': null,
      'email': 'admin@diamondagritech.com',
      'device_id': null,
      'must_change_pin': false,
      'failed_login_attempts': 0,
      'locked_until': null,
      'blocked_at': null,
      'blocked_reason': null,
      'blocked_by': null,
      'created_at': '2026-10-15T09:00:00.000Z',
      'updated_at': '2026-10-15T09:00:00.000Z',
    };

    test('parses employee profile from JSON correctly', () {
      final UserProfile profile = UserProfile.fromJson(sampleEmployeeJson);

      expect(profile.id, '11111111-1111-1111-1111-111111111111');
      expect(profile.role, UserRole.employee);
      expect(profile.status, UserStatus.active);
      expect(profile.isActive, isTrue);
      expect(profile.isBlocked, isFalse);
      expect(profile.employeeCode, 'DA-014');
      expect(profile.fullName, 'Suresh Patel');
      expect(profile.phone, '+919876543210');
      expect(profile.deviceId, 'android-device-abc-123');
      expect(profile.mustChangePin, isTrue);
    });

    test('parses admin profile from JSON correctly', () {
      final UserProfile profile = UserProfile.fromJson(sampleAdminJson);

      expect(profile.id, '22222222-2222-2222-2222-222222222222');
      expect(profile.role, UserRole.admin);
      expect(profile.status, UserStatus.active);
      expect(profile.employeeCode, isNull);
      expect(profile.mustChangePin, isFalse);
    });

    test('identifies blocked profile status', () {
      final UserProfile profile = UserProfile.fromJson(<String, dynamic>{
        ...sampleEmployeeJson,
        'status': 'blocked',
        'blocked_at': '2026-10-15T11:00:00.000Z',
        'blocked_reason': 'Suspicious repeated mock location',
      });

      expect(profile.isBlocked, isTrue);
      expect(profile.isActive, isFalse);
      expect(profile.blockedReason, 'Suspicious repeated mock location');
    });

    test('toJson produces valid serializable map', () {
      final UserProfile profile = UserProfile.fromJson(sampleEmployeeJson);
      final Map<String, dynamic> json = profile.toJson();

      expect(json['id'], profile.id);
      expect(json['role'], 'employee');
      expect(json['status'], 'active');
      expect(json['employee_code'], 'DA-014');
      expect(json['full_name'], 'Suresh Patel');
    });

    test('copyWith updates specified fields', () {
      final UserProfile original = UserProfile.fromJson(sampleEmployeeJson);
      final UserProfile updated = original.copyWith(
        mustChangePin: false,
        deviceId: 'new-device-id',
      );

      expect(updated.mustChangePin, isFalse);
      expect(updated.deviceId, 'new-device-id');
      expect(updated.id, original.id);
      expect(updated.fullName, original.fullName);
    });
  });
}
