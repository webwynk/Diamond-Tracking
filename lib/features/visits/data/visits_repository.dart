import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../requests/data/photo_upload.dart';
import '../../routes/domain/geo_point.dart';
import '../domain/visit.dart';

abstract interface class VisitsRepository {
  /// A day's visits, in time order.
  Future<List<Visit>> forDay(int dayId);

  /// How many visits these duty days have (the admin dashboard's total).
  Future<int> countForDays(List<int> dayIds);

  /// Uploads a JPEG and returns its photo id, `visit-<uuid>`. The uuid is the
  /// new visit's id.
  Future<String> uploadPhoto(Uint8List jpeg);

  /// Saves a visit to today's duty. Sending the same photo id again does not
  /// add a second visit.
  Future<void> add({
    required String photoId,
    required String storeName,
    required String? note,
    required GeoPoint? location,
    required DateTime capturedAt,
    bool mocked = false,
    int? accuracyM,
  });

  /// The photo; [small] asks for the small list version (L57).
  PhotoSource photo(String visitId, {bool small = false});
}

/// The visit id inside a visit photo id.
String visitIdOf(String photoId) => photoId.substring('visit-'.length);

class SupabaseVisitsRepository implements VisitsRepository {
  SupabaseVisitsRepository(this._client, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final SupabaseClient _client;
  final http.Client _http;

  @override
  Future<List<Visit>> forDay(int dayId) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('visits')
        .select(
          'id, store_name, note, from_gallery, lat_e6, lng_e6, photo_id, '
          'photo_removed_at, captured_at, mocked, accuracy_m',
        )
        .eq('duty_day_id', dayId)
        .order('captured_at');
    return rows.map(Visit.fromRow).toList();
  }

  @override
  Future<int> countForDays(List<int> dayIds) async {
    if (dayIds.isEmpty) return 0;
    final PostgrestResponse<List<Map<String, dynamic>>> res = await _client
        .from('visits')
        .select('id')
        .inFilter('duty_day_id', dayIds)
        .count(CountOption.exact);
    return res.count;
  }

  @override
  Future<String> uploadPhoto(Uint8List jpeg) =>
      uploadSignedPhoto(_client, _http, jpeg, kind: 'visit');

  @override
  Future<void> add({
    required String photoId,
    required String storeName,
    required String? note,
    required GeoPoint? location,
    required DateTime capturedAt,
    bool mocked = false,
    int? accuracyM,
  }) => _client.rpc<Object?>(
    'add_visit',
    params: <String, Object?>{
      'p_id': visitIdOf(photoId),
      'p_store_name': storeName,
      'p_note': note,
      'p_from_gallery': location == null,
      'p_lat_e6': location == null ? null : (location.lat * 1e6).round(),
      'p_lng_e6': location == null ? null : (location.lng * 1e6).round(),
      'p_photo_id': photoId,
      'p_captured_at': capturedAt.toUtc().toIso8601String(),
      'p_mocked': location != null && mocked,
      'p_accuracy_m': location == null ? null : accuracyM,
    },
  );

  @override
  PhotoSource photo(String visitId, {bool small = false}) =>
      PhotoSource.of(_client, 'visit_id=$visitId${small ? '&size=small' : ''}');
}
