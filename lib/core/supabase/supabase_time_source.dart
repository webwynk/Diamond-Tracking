import 'dart:io';

import '../time/server_clock.dart';

/// Reads the server time from the `Date` header of a lightweight Supabase
/// request (the Auth health check), so it works before any table exists.
///
/// The header has whole-second precision, which is enough for minute-level
/// rules, so no database function is needed for the time (L50).
ServerTimeSource supabaseTimeSource({
  required String supabaseUrl,
  required String publishableKey,
  Duration timeout = const Duration(seconds: 8),
}) {
  return () async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final Uri uri = Uri.parse(supabaseUrl).replace(path: '/auth/v1/health');
      final HttpClientRequest request = await client
          .getUrl(uri)
          .timeout(timeout);
      request.headers.set('apikey', publishableKey);
      final HttpClientResponse response = await request.close().timeout(
        timeout,
      );
      await response.drain<void>();
      final String? date = response.headers.value(HttpHeaders.dateHeader);
      if (date == null) {
        throw const HttpException('Server reply had no Date header');
      }
      return HttpDate.parse(date);
    } finally {
      client.close(force: true);
    }
  };
}
