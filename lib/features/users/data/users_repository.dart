import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_log.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_failure.dart';
import '../../duty/data/duty_permit_lookup.dart';
import '../domain/profile.dart';

/// Field errors from the server, keyed by field name.
class FieldErrors implements Exception {
  const FieldErrors(this.fields);
  final Map<String, String> fields;
}

abstract interface class UsersRepository {
  Future<List<Profile>> list();
  Future<Profile?> byId(String id);
  Future<Profile> create(ProfileDraft draft, {required String tempPin});
  Future<Profile> update(String id, ProfileDraft draft);
  Future<void> resetPin(String id, {required String tempPin});

  /// Signs [id] out of their phone and frees the account for another phone,
  /// without changing the password. False if no phone held it.
  Future<bool> releasePhone(String id);

  /// Whether the admin has allowed [userId] to do duty on on [day] (an IST
  /// date) and it is not used yet.
  Future<bool> dutyOnAllowed(String userId, DateTime day);

  /// Lets [userId] do duty on today outside 5:00 to 8:30 AM, once.
  Future<void> allowDutyOn(String userId, {String? note});

  /// Takes back a permission that is not used yet.
  Future<void> revokeDutyOn(String userId);
}

class SupabaseUsersRepository implements UsersRepository {
  SupabaseUsersRepository(this._client);

  final SupabaseClient _client;

  static const String _columns =
      'id, user_code, full_name, phone, contact_email, role, is_active, active_device_id';

  @override
  Future<List<Profile>> list() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('profiles')
        .select(_columns)
        .order('full_name');
    return rows.map(Profile.fromRow).toList();
  }

  @override
  Future<Profile?> byId(String id) async {
    final Map<String, dynamic>? row = await _client
        .from('profiles')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Profile.fromRow(row);
  }

  @override
  Future<Profile> create(ProfileDraft draft, {required String tempPin}) async {
    final Map<String, dynamic> data = await _invoke(<String, Object?>{
      'action': 'create',
      'user_code': draft.userCode.trim(),
      'full_name': draft.fullName.trim(),
      'phone': draft.phone.trim(),
      'contact_email': draft.contactEmail.trim(),
      'role': draft.role.name,
      'temp_pin': tempPin,
    });
    return Profile.fromRow(data['profile'] as Map<String, dynamic>);
  }

  @override
  Future<Profile> update(String id, ProfileDraft draft) async {
    final Map<String, dynamic> data = await _invoke(<String, Object?>{
      'action': 'update',
      'id': id,
      'full_name': draft.fullName.trim(),
      'phone': draft.phone.trim(),
      'contact_email': draft.contactEmail.trim(),
      'role': draft.role.name,
      'is_active': draft.isActive,
    });
    return Profile.fromRow(data['profile'] as Map<String, dynamic>);
  }

  @override
  Future<void> resetPin(String id, {required String tempPin}) async {
    await _invoke(<String, Object?>{
      'action': 'reset_pin',
      'id': id,
      'temp_pin': tempPin,
    });
  }

  @override
  Future<bool> releasePhone(String id) async {
    try {
      final Object? held = await _client.rpc<Object?>(
        'release_phone',
        params: <String, Object?>{'p_user': id},
      );
      return held == true;
    } on Object catch (e, st) {
      final AuthFailure failure = mapAuthError(e);
      if (failure == AuthFailure.unknown) {
        AppLog.failure('UsersRepository.releasePhone', e, st);
      }
      throw failure;
    }
  }

  Future<Map<String, dynamic>> _invoke(Map<String, Object?> body) async {
    try {
      final FunctionResponse res = await _client.functions.invoke(
        'admin-users',
        body: body,
      );
      return (res.data as Map<String, dynamic>?) ?? <String, dynamic>{};
    } on FunctionException catch (e, st) {
      final Object? details = e.details;
      if (details is Map && details['fields'] is Map) {
        throw FieldErrors(
          (details['fields'] as Map).map(
            (Object? k, Object? v) => MapEntry<String, String>('$k', '$v'),
          ),
        );
      }
      final AuthFailure failure = mapAuthError(e);
      if (failure == AuthFailure.unknown) {
        AppLog.failure('UsersRepository', e, st);
      }
      throw failure;
    } on Object catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<bool> dutyOnAllowed(String userId, DateTime day) =>
      hasUnusedDutyPermit(_client, userId, day);

  @override
  Future<void> allowDutyOn(String userId, {String? note}) =>
      _client.rpc<Object?>(
        'allow_duty_on',
        params: <String, Object?>{
          'p_user': userId,
          'p_note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
        },
      );

  @override
  Future<void> revokeDutyOn(String userId) => _client.rpc<Object?>(
    'revoke_duty_on',
    params: <String, Object?>{'p_user': userId},
  );
}
