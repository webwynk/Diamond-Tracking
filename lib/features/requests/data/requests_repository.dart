import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/ist.dart';
import '../../duty/domain/duty_day.dart';
import '../domain/app_request.dart';
import 'photo_upload.dart';

export 'photo_upload.dart' show PhotoSource;

abstract interface class RequestsRepository {
  /// The user's own requests, newest first.
  /// The newest [limit] requests of [userId].
  Future<List<AppRequest>> mine(String userId, {int limit = requestPageSize});

  /// Everyone's requests for the admin: waiting ones oldest first, or the
  /// latest 100 of any status.
  /// Waiting requests (oldest first), or the newest of all; at most [limit].
  Future<List<AppRequest>> forAdmin({
    required bool pendingOnly,
    int limit = requestPageSize,
  });

  Future<AppRequest?> byId(int id);

  Future<void> requestAttendance({
    required DateTime day,
    required int dutyOnMinute,
    required int dutyOffMinute,
    required String message,
    required String photoId,
  });

  Future<void> requestLeave({
    required LeaveType type,
    required List<DateTime> dates,
    required String message,
    String? proofId,
  });

  Future<void> cancel(int id);

  Future<void> decide(int id, DayStatus decision, String? note);

  /// Uploads a JPEG and returns its photo id for a request.
  Future<String> uploadPhoto(Uint8List jpeg);

  PhotoSource photo(int requestId);
}

/// Requests loaded per page; "Show more" adds this many (L70).
const int requestPageSize = 100;

String _hhmm(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

class SupabaseRequestsRepository implements RequestsRepository {
  SupabaseRequestsRepository(this._client, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final SupabaseClient _client;
  final http.Client _http;

  static const String _columns =
      'id, user_id, kind, status, day, duty_on_at, duty_off_at, leave_type, '
      'dates, message, photo_id, photo_removed_at, decision, decision_note, '
      'decided_at, created_at';

  List<AppRequest> _rows(List<Map<String, dynamic>> rows) =>
      rows.map(AppRequest.fromRow).toList();

  @override
  Future<List<AppRequest>> mine(
    String userId, {
    int limit = requestPageSize,
  }) async => _rows(
    await _client
        .from('requests')
        .select(_columns)
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit),
  );

  @override
  Future<List<AppRequest>> forAdmin({
    required bool pendingOnly,
    int limit = requestPageSize,
  }) async {
    if (pendingOnly) {
      return _rows(
        await _client
            .from('requests')
            .select(_columns)
            .eq('status', 'pending')
            .order('created_at')
            .order('id')
            .limit(limit),
      );
    }
    return _rows(
      await _client
          .from('requests')
          .select(_columns)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit),
    );
  }

  @override
  Future<AppRequest?> byId(int id) async {
    final Map<String, dynamic>? row = await _client
        .from('requests')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : AppRequest.fromRow(row);
  }

  @override
  Future<void> requestAttendance({
    required DateTime day,
    required int dutyOnMinute,
    required int dutyOffMinute,
    required String message,
    required String photoId,
  }) => _client.rpc<Object?>(
    'request_attendance',
    params: <String, Object?>{
      'p_day': isoDate(day),
      'p_duty_on': _hhmm(dutyOnMinute),
      'p_duty_off': _hhmm(dutyOffMinute),
      'p_message': message,
      'p_photo_id': photoId,
    },
  );

  @override
  Future<void> requestLeave({
    required LeaveType type,
    required List<DateTime> dates,
    required String message,
    String? proofId,
  }) => _client.rpc<Object?>(
    'request_leave',
    params: <String, Object?>{
      'p_type': type.wire,
      'p_dates': dates.map(isoDate).toList(),
      'p_message': message,
      'p_proof_id': proofId,
    },
  );

  @override
  Future<void> cancel(int id) => _client.rpc<Object?>(
    'cancel_request',
    params: <String, Object?>{'p_request_id': id},
  );

  @override
  Future<void> decide(int id, DayStatus decision, String? note) =>
      _client.rpc<Object?>(
        'decide_request',
        params: <String, Object?>{
          'p_request_id': id,
          'p_decision': decision.wire,
          'p_note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
        },
      );

  @override
  Future<String> uploadPhoto(Uint8List jpeg) =>
      uploadSignedPhoto(_client, _http, jpeg);

  @override
  PhotoSource photo(int requestId) =>
      PhotoSource.of(_client, 'request_id=$requestId');
}
