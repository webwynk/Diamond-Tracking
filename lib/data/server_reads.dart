import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors/app_exceptions.dart';

/// Two server reads several admin screens share, so they are written once.
abstract final class ServerReads {
  const ServerReads._();

  /// The server's clock (UTC): the only clock "today", "stale" and "hours so
  /// far" may be judged on (Rule 3). Throws [ServerException] if the answer is
  /// not a time.
  static Future<DateTime> serverTime(SupabaseClient client) async {
    final response = await client.rpc<dynamic>('server_time');
    if (response is! String) {
      throw const ServerException('The server gave an unexpected time.');
    }
    return DateTime.parse(response).toUtc();
  }

  /// The server's running distance for a duty session that is still open
  /// (`admin_session_distance()`; a session's stored total is only written when
  /// it closes), or null when it cannot be had, for example before the function
  /// is installed. Never guessed on the phone.
  static Future<double?> runningDistanceKm(
    SupabaseClient client,
    Object? sessionId,
  ) async {
    try {
      final value = await client.rpc<dynamic>(
        'admin_session_distance',
        params: <String, dynamic>{'p_session': sessionId},
      );
      if (value is num) return value.toDouble();
      return double.tryParse('$value');
    } on Object catch (e) {
      debugPrint('ServerReads: no running distance: $e');
      return null;
    }
  }
}
