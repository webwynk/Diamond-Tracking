import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/duty_day.dart';

/// Duty on, duty off and today's record. Every call needs the internet.
abstract interface class DutyRepository {
  /// The signed-in user's record for [day] (an IST date), if any.
  Future<DutyDay?> forDay(String userId, DateTime day);

  /// Starts today's duty from this phone.
  Future<DutyStart> dutyOn(String deviceId);

  /// Today's duty is on but this phone has no upload pass (app data was
  /// cleared): a new pass for this phone.
  Future<DutyStart> resume(String deviceId);

  /// Ends the duty at [offAt] (the server caps it to now and 11:00 PM).
  Future<DutyDay> dutyOff(int dayId, DateTime offAt);
}

class SupabaseDutyRepository implements DutyRepository {
  SupabaseDutyRepository(this._client);

  final SupabaseClient _client;

  static const String _columns =
      'id, day, status, duty_on_at, duty_off_at, end_reason, worked_minutes';

  @override
  Future<DutyDay?> forDay(String userId, DateTime day) async {
    final String date =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final Map<String, dynamic>? row = await _client
        .from('duty_days')
        .select(_columns)
        .eq('user_id', userId)
        .eq('day', date)
        .maybeSingle();
    return row == null ? null : DutyDay.fromJson(row);
  }

  @override
  Future<DutyStart> dutyOn(String deviceId) async {
    final Object? data = await _client.rpc<Object?>(
      'duty_on',
      params: <String, Object?>{'p_device_id': deviceId},
    );
    return DutyStart.fromJson(data! as Map<String, dynamic>);
  }

  @override
  Future<DutyStart> resume(String deviceId) async {
    final Object? data = await _client.rpc<Object?>(
      'duty_resume',
      params: <String, Object?>{'p_device_id': deviceId},
    );
    return DutyStart.fromJson(data! as Map<String, dynamic>);
  }

  @override
  Future<DutyDay> dutyOff(int dayId, DateTime offAt) async {
    final Object? data = await _client.rpc<Object?>(
      'duty_off',
      params: <String, Object?>{
        'p_day_id': dayId,
        'p_off_at': offAt.toUtc().toIso8601String(),
      },
    );
    return DutyDay.fromJson(data! as Map<String, dynamic>);
  }
}
