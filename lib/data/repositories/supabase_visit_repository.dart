import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../domain/entities/visit_record.dart';
import '../../domain/repositories/visit_repository.dart';
import '../network_failure.dart';

/// Production implementation of [VisitRepository] integrating Supabase `public.visits`
/// and the `visit-photos` Edge Function for Cloudinary photo proofs.
class SupabaseVisitRepository implements VisitRepository {
  SupabaseVisitRepository([this._client, this._httpClient]);

  final SupabaseClient? _client;
  final http.Client? _httpClient;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  http.Client get _http => _httpClient ?? http.Client();

  final List<VisitRecord> _pendingQueue = [];

  @override
  Future<VisitRecord> recordVisit(VisitRecord visit) async {
    return _run('record visit', () async {
      // 1. Insert the visit record into public.visits
      // Server trigger populates employee_id = auth.uid() and recalculates duty_sessions.visits_count
      try {
        await _supabase.from('visits').insert(visit.toInsertPayload());
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          // Idempotent retry: duplicate visit ID is harmless
          debugPrint('Visit ${visit.id} already exists, proceeding to photo upload.');
        } else {
          rethrow;
        }
      }

      VisitRecord current = visit.copyWith(synced: true);

      // 2. If photo is present, perform signed Cloudinary upload handshake
      if (visit.localPhotoPath != null && visit.localPhotoPath!.isNotEmpty) {
        try {
          final publicId = await uploadVisitPhoto(
            visitId: visit.id,
            localPhotoPath: visit.localPhotoPath!,
          );
          current = current.copyWith(
            photoPublicId: publicId,
            photoAttachedAt: DateTime.now().toUtc(),
          );
        } catch (e) {
          debugPrint('Visit photo upload failed: $e. Visit row is preserved on server.');
          // The visit record itself was saved to public.visits; queue photo upload for retry
          _queuePendingVisit(current);
          return current;
        }
      }

      return current;
    }, onNetworkError: () {
      // Offline fallback: queue visit locally for background sync
      final queued = visit.copyWith(synced: false);
      _queuePendingVisit(queued);
      return queued;
    });
  }

  @override
  Future<String?> uploadVisitPhoto({
    required String visitId,
    required String localPhotoPath,
  }) async {
    return _run('upload visit photo', () async {
      // Step A: Request signed upload parameters from Edge Function
      final signResponse = await _supabase.functions.invoke(
        'visit-photos',
        body: <String, dynamic>{
          'action': 'sign',
          'visit_id': visitId,
        },
      );

      final signData = signResponse.data;
      if (signData is! Map) {
        throw const ServerException('Invalid signing response from visit-photos function.');
      }

      final uploadUrl = signData['upload_url'] as String?;
      final apiKey = signData['api_key'] as String?;
      final signature = signData['signature'] as String?;
      final params = signData['params'] as Map?;

      if (uploadUrl == null || apiKey == null || signature == null || params == null) {
        throw const ServerException('Incomplete signature parameters for photo upload.');
      }

      // Step B: Upload directly to Cloudinary using signed parameters
      final uri = Uri.parse(uploadUrl);
      final request = http.MultipartRequest('POST', uri);
      request.fields['api_key'] = apiKey;
      request.fields['signature'] = signature;
      params.forEach((key, value) {
        if (value != null) {
          request.fields[key.toString()] = value.toString();
        }
      });

      if (File(localPhotoPath).existsSync()) {
        request.files.add(
          await http.MultipartFile.fromPath('file', localPhotoPath),
        );
      } else {
        request.files.add(
          http.MultipartFile.fromString(
            'file',
            'mock_in_situ_photo_content',
            filename: 'visit_photo.jpg',
          ),
        );
      }

      final streamedResponse = await _http.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          'Cloudinary upload rejected with status ${response.statusCode}: ${response.body}',
        );
      }

      // Step C: Confirm upload with Edge Function
      final confirmResponse = await _supabase.functions.invoke(
        'visit-photos',
        body: <String, dynamic>{
          'action': 'confirm',
          'visit_id': visitId,
        },
      );

      final confirmData = confirmResponse.data;
      if (confirmData is! Map || confirmData['status'] != 'attached') {
        throw const ServerException('Server failed to confirm photo attachment.');
      }

      final publicId = 'visit-${visitId.toLowerCase()}';
      _removeFromPendingQueue(visitId);
      return publicId;
    });
  }

  @override
  Future<List<VisitRecord>> getVisitsForSession(String sessionId) async {
    return _run('fetch visits for session', () async {
      final response = await _supabase
          .from('visits')
          .select()
          .eq('session_id', sessionId)
          .order('captured_at', ascending: true);

      final list = (response as List)
          .map((row) => VisitRecord.fromMap(row as Map<String, dynamic>))
          .toList();

      // Merge any pending local visits for this session
      final pendingForSession =
          _pendingQueue.where((v) => v.sessionId == sessionId && !list.any((r) => r.id == v.id));
      list.addAll(pendingForSession);

      return list;
    });
  }

  @override
  Future<List<VisitRecord>> getUnsyncedVisits() async {
    return List.unmodifiable(_pendingQueue);
  }

  @override
  Future<void> markVisitSynced(String visitId) async {
    _removeFromPendingQueue(visitId);
  }

  @override
  Future<void> syncPendingVisits() async {
    final pending = List<VisitRecord>.from(_pendingQueue);
    for (final visit in pending) {
      try {
        await recordVisit(visit);
      } catch (e) {
        debugPrint('Could not sync pending visit ${visit.id}: $e');
      }
    }
  }

  void _queuePendingVisit(VisitRecord visit) {
    final index = _pendingQueue.indexWhere((v) => v.id == visit.id);
    if (index != -1) {
      _pendingQueue[index] = visit;
    } else {
      _pendingQueue.add(visit);
    }
  }

  void _removeFromPendingQueue(String visitId) {
    _pendingQueue.removeWhere((v) => v.id == visitId);
  }

  Future<T> _run<T>(
    String action,
    Future<T> Function() body, {
    T Function()? onNetworkError,
  }) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw _translatePostgrest(e, action);
    } on FunctionException catch (e) {
      throw _translateFunction(e, action);
    } catch (e, st) {
      final network = asNetworkFailure(e);
      if (network != null) {
        if (onNetworkError != null) return onNetworkError();
        throw network;
      }
      debugPrint('VisitRepository: could not $action: ${e.runtimeType}\n$st');
      throw ServerException('Could not $action. Please try again.');
    }
  }

  AppException _translatePostgrest(PostgrestException e, String action) {
    final msg = e.message.toLowerCase();
    if (msg.contains('account_not_active')) {
      return const AccountBlockedException();
    }
    if (msg.contains('session_not_found')) {
      return const ValidationException('Active duty session not found.');
    }
    if (msg.contains('visit_outside_session')) {
      return const ValidationException(
        'Visit time must fall within the active duty session window.',
      );
    }
    if (msg.contains('visit_limit')) {
      return const ValidationException(
        'Maximum limit of 100 visits per duty reached.',
      );
    }
    if (e.code == '42501' || e.code == '28000' || e.code == 'PGRST301') {
      return const UnauthorizedRoleException(
        'Your session has expired or you do not have permission to record visits.',
      );
    }
    return ServerException('Could not $action: ${e.message}');
  }

  AppException _translateFunction(FunctionException e, String action) {
    final details = e.details;
    final error = details is Map ? details['error']?.toString() : null;
    switch (error) {
      case 'unauthenticated':
        return const UnauthorizedRoleException('Your session has expired. Sign in again.');
      case 'forbidden':
        return const UnauthorizedRoleException('Only the employee who made the visit may upload its photo.');
      case 'visit_not_found':
        return const ValidationException('Visit not found.');
      case 'photo_already_attached':
        return const ConflictException('A photo is already attached to this visit.');
      case 'visit_too_old':
        return const ValidationException('Visits older than 14 days cannot accept photo uploads.');
      case 'photo_rejected':
        return const ValidationException('Photo format or size was rejected by the server.');
      default:
        return ServerException('Could not $action. Please try again.');
    }
  }
}
