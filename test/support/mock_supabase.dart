import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A response with a JSON body, as PostgREST and Edge Functions send them.
http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

/// A real [SupabaseClient] whose network is replaced by [answer], so
/// repository tests exercise the real client code and only the server is
/// pretend. Every request received is kept in [requests].
class MockSupabase {
  MockSupabase(http.Response Function(http.Request request) answer) {
    client = SupabaseClient(
      'https://test.supabase.co',
      'anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final response = answer(request);
        // The Postgrest parser reads response.request, which a hand-made
        // response lacks.
        return http.Response(
          response.body,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
    );
  }

  /// A client whose every call fails as if the phone had no connection.
  MockSupabase.offline() {
    client = SupabaseClient(
      'https://test.supabase.co',
      'anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        throw http.ClientException('offline');
      }),
    );
  }

  late final SupabaseClient client;
  final List<http.Request> requests = <http.Request>[];
}
