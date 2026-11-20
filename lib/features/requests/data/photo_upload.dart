import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';

/// Where to load a photo from: the photos function, signed in.
class PhotoSource {
  const PhotoSource({required this.url, required this.headers});

  /// [query] is `request_id=5` or `visit_id=<uuid>`.
  factory PhotoSource.of(SupabaseClient client, String query) => PhotoSource(
    url: '${Env.supabaseUrl}/functions/v1/photos?$query',
    headers: <String, String>{
      'apikey': Env.supabasePublishableKey,
      'Authorization':
          'Bearer ${client.auth.currentSession?.accessToken ?? ''}',
    },
  );

  final String url;
  final Map<String, String> headers;
}

/// Cloudinary did not take the file.
class PhotoUploadFailed implements Exception {
  const PhotoUploadFailed();
}

/// Asks the photos function to sign an upload, then posts the JPEG straight
/// to Cloudinary. Returns the photo id: `req-<uuid>`, or `visit-<uuid>` when
/// [kind] is `visit`.
Future<String> uploadSignedPhoto(
  SupabaseClient client,
  http.Client httpClient,
  Uint8List jpeg, {
  String kind = 'request',
}) async {
  final FunctionResponse signed = await client.functions.invoke(
    'photos',
    body: <String, Object?>{'action': 'sign', 'kind': kind},
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
  final http.StreamedResponse res = await httpClient
      .send(req)
      .timeout(const Duration(seconds: 60));
  await res.stream.drain<void>();
  if (res.statusCode != 200) throw const PhotoUploadFailed();
  return data['public_id'] as String;
}
