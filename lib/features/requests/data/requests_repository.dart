import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../duty/domain/duty_day.dart';
import '../domain/app_request.dart';
import '../domain/request_failure.dart';

/// Where to load a request's photo from: the photos function, signed in.
class PhotoSource {
  const PhotoSource({required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;
}

abstract interface class RequestsRepository {
  /// The user's own requests, newest first.
  Future<List<AppRequest>> mine(String userId);

  /// Everyone's requests for the admin: waiting ones oldest first, or the
  /// latest 100 of any status.
  Future<List<AppRequest>> forAdmin({required bool pendingOnly});

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

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

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
      'dates, message, photo_id, decision, decision_note, decided_at, created_at';

  List<AppRequest> _rows(List<Map<String, dynamic>> rows) =>
      rows.map(AppRequest.fromRow).toList();

  @override
  Future<List<AppRequest>> mine(String userId) async => _rows(
    await _client
        .from('requests')
        .select(_columns)
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100),
  );

  @override
  Future<List<AppRequest>> forAdmin({required bool pendingOnly}) async {
    if (pendingOnly) {
      return _rows(
        await _client
            .from('requests')
            .select(_columns)
            .eq('status', 'pending')
            .order('created_at')
            .limit(200),
      );
    }
    return _rows(
      await _client
          .from('requests')
          .select(_columns)
          .order('created_at', ascending: false)
          .limit(100),
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
  Future<String> uploadPhoto(Uint8List jpeg) async {
    final FunctionResponse signed = await _client.functions.invoke(
      'photos',
      body: <String, Object?>{'action': 'sign'},
    );
    final Map<String, dynamic> data = signed.data as Map<String, dynamic>;
    final http.MultipartRequest req =
        http.MultipartRequest('POST', Uri.parse(data['upload_url'] as String))
          ..fields.addAll(
            (data['fields'] as Map<String, dynamic>).map(
              (String k, dynamic v) => MapEntry<String, String>(k, '$v'),
            ),
          )
          ..files.add(
            http.MultipartFile.fromBytes('file', jpeg, filename: 'photo.jpg'),
          );
    final http.StreamedResponse res = await _http
        .send(req)
        .timeout(const Duration(seconds: 60));
    await res.stream.drain<void>();
    if (res.statusCode != 200) {
      throw const RequestException(RequestFailure.photoUploadFailed);
    }
    return data['public_id'] as String;
  }

  @override
  PhotoSource photo(int requestId) => PhotoSource(
    url: '${Env.supabaseUrl}/functions/v1/photos?request_id=$requestId',
    headers: <String, String>{
      'apikey': Env.supabasePublishableKey,
      'Authorization':
          'Bearer ${_client.auth.currentSession?.accessToken ?? ''}',
    },
  );
}
