import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/track_break.dart';

/// Sends queued points and breaks to the server with a day's upload pass.
abstract interface class TrackUploader {
  /// Returns how many points the server stored (duplicates are skipped).
  Future<int> uploadPoints(
    int dayId,
    String pass,
    List<Map<String, Object?>> points,
  );

  Future<void> reportBreak(int dayId, String pass, TrackBreak trackBreak);

  /// Duty off that was pressed while offline.
  Future<void> dutyOff(int dayId, String pass, DateTime offAt);
}

/// The server refused the upload for good (the pass was replaced after a
/// password reset, the duty was deleted, or the data was malformed). Trying
/// again will not help, so the batch is dropped.
class UploadRejected implements Exception {
  const UploadRejected(this.reason);

  final String reason;

  @override
  String toString() => 'UploadRejected($reason)';
}

/// Uses a Supabase client that has no sign-in session: the pass is the
/// permission. The tracker service makes its own client, so it never touches
/// the app's session (two engines refreshing one session would sign the user
/// out).
class SupabaseTrackUploader implements TrackUploader {
  SupabaseTrackUploader(this._client);

  final SupabaseClient _client;

  static const Set<String> _permanent = <String>{
    'invalid_upload_pass',
    'duty_not_found',
    'invalid_points',
  };

  @override
  Future<int> uploadPoints(
    int dayId,
    String pass,
    List<Map<String, Object?>> points,
  ) => _call(() async {
    final Object? stored = await _client.rpc<Object?>(
      'upload_points_with_pass',
      params: <String, Object?>{
        'p_day_id': dayId,
        'p_pass': pass,
        'p_points': points,
      },
    );
    return (stored as num?)?.toInt() ?? 0;
  });

  @override
  Future<void> reportBreak(int dayId, String pass, TrackBreak trackBreak) =>
      _call(() async {
        await _client.rpc<Object?>(
          'report_break_with_pass',
          params: <String, Object?>{
            'p_day_id': dayId,
            'p_pass': pass,
            'p_from': trackBreak.from.toUtc().toIso8601String(),
            'p_to': trackBreak.to.toUtc().toIso8601String(),
            'p_kind': trackBreak.kind.wire,
          },
        );
      });

  @override
  Future<void> dutyOff(int dayId, String pass, DateTime offAt) =>
      _call(() async {
        await _client.rpc<Object?>(
          'duty_off_with_pass',
          params: <String, Object?>{
            'p_day_id': dayId,
            'p_pass': pass,
            'p_off_at': offAt.toUtc().toIso8601String(),
          },
        );
      });

  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      final String reason = _permanent.firstWhere(
        e.message.contains,
        orElse: () => '',
      );
      if (reason.isNotEmpty) throw UploadRejected(reason);
      rethrow;
    }
  }
}
