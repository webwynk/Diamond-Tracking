import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/env.dart';

/// Which picture of a visit to fetch.
enum VisitPhotoSize { thumb, full }

/// Where to fetch a visit picture, and the sign-in to fetch it with.
class VisitPhotoRequest {
  const VisitPhotoRequest({required this.url, required this.headers});

  /// The `visit-photos` function address for one visit and size, with the
  /// admin's [accessToken], or null when nobody is signed in.
  static VisitPhotoRequest? build({
    required String functionsBaseUrl,
    required String publishableKey,
    required String? accessToken,
    required String visitId,
    required VisitPhotoSize size,
  }) {
    if (accessToken == null) return null;
    final url = Uri.parse(functionsBaseUrl).replace(
      queryParameters: <String, String>{'visit_id': visitId, 'size': size.name},
    );
    return VisitPhotoRequest(
      url: url.toString(),
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
        'apikey': publishableKey,
      },
    );
  }

  final String url;
  final Map<String, String> headers;
}

/// Builds the request for a visit picture, or null when nobody is signed in.
typedef VisitPhotoRequestBuilder =
    VisitPhotoRequest? Function(String visitId, VisitPhotoSize size);

/// The one way a phone gets a visit picture: from the admin-only `visit-photos`
/// function, with the admin's own sign-in. The function checks it again and
/// returns the picture itself; no Cloudinary address is ever given to the phone
/// (PRD F10, docs/10).
final visitPhotoRequestProvider = Provider<VisitPhotoRequestBuilder>((ref) {
  return (visitId, size) => VisitPhotoRequest.build(
    functionsBaseUrl: '${Env.supabaseUrl}/functions/v1/visit-photos',
    publishableKey: Env.supabasePublishableKey,
    accessToken: Supabase.instance.client.auth.currentSession?.accessToken,
    visitId: visitId,
    size: size,
  );
});
