import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/services/visit_photo_vault.dart';
import '../../core/utils/failure_log.dart';
import '../../domain/entities/visit_record.dart';
import '../../domain/repositories/visit_queue_store.dart';
import '../../domain/repositories/visit_repository.dart';
import '../network_failure.dart';

/// Production implementation of [VisitRepository] integrating Supabase `public.visits`
/// and the `visit-photos` Edge Function for Cloudinary photo proofs.
///
/// A visit is saved on the phone ([VisitQueueStore]) BEFORE anything is sent, so
/// it survives a restart, a force-kill and a long time offline. It leaves the
/// phone only when the server holds the row and the photo, or has refused it for
/// good. Anything else (no internet, a server error, an expired sign-in) leaves
/// it waiting for [syncPendingVisits].
class SupabaseVisitRepository implements VisitRepository {
  SupabaseVisitRepository(
    this._queue, [
    this._client,
    this._httpClient,
    VisitPhotoVault? vault,
    this._currentEmployeeId,
  ]) : _vault = vault ?? DeviceVisitPhotoVault();

  final SupabaseClient? _client;
  final http.Client? _httpClient;
  final VisitQueueStore _queue;
  final VisitPhotoVault _vault;

  /// Who is signed in; when null, the Supabase session says.
  final String? Function()? _currentEmployeeId;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  late final http.Client _http = _httpClient ?? http.Client();

  /// Visits being sent right now, so the save and the retry timer never send
  /// the same one at the same time.
  final Set<String> _inFlight = <String>{};
  bool _syncing = false;

  @override
  Future<VisitRecord> recordVisit(VisitRecord visit) async {
    final saved = await _saveOnPhone(visit);
    final outcome = await _deliver(PendingVisit(visit: saved, rowSent: false));
    return saved.copyWith(synced: outcome.rowSent);
  }

  /// Sends one photo: asks the server for a signed upload, uploads straight to
  /// Cloudinary, then tells the server it arrived (docs/10).
  Future<void> _sendPhoto(String visitId, String localPhotoPath) {
    return _run('upload visit photo', () async {
      // Step A: Request signed upload parameters from Edge Function
      final signResponse = await _supabase.functions.invoke(
        'visit-photos',
        body: <String, dynamic>{'action': 'sign', 'visit_id': visitId},
      );

      final signData = signResponse.data;
      if (signData is! Map) {
        throw const ServerException(
          'Invalid signing response from visit-photos function.',
        );
      }

      final uploadUrl = signData['upload_url'] as String?;
      final apiKey = signData['api_key'] as String?;
      final signature = signData['signature'] as String?;
      final params = signData['params'] as Map?;

      if (uploadUrl == null ||
          apiKey == null ||
          signature == null ||
          params == null) {
        throw const ServerException(
          'Incomplete signature parameters for photo upload.',
        );
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

      if (!File(localPhotoPath).existsSync()) {
        throw const ValidationException(
          'The photo file is no longer on the phone.',
        );
      }
      request.files.add(
        await http.MultipartFile.fromPath('file', localPhotoPath),
      );

      final streamedResponse = await _http.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 201) {
        final status = response.statusCode;
        // A 4xx means this photo will never be accepted as sent; anything else
        // (5xx, 408, 429) may work on a later try.
        if (status >= 400 && status < 500 && status != 408 && status != 429) {
          throw ValidationException(
            'Cloudinary refused the photo (status $status).',
          );
        }
        throw ServerException('Cloudinary upload failed with status $status.');
      }

      // Step C: Confirm upload with Edge Function
      final confirmResponse = await _supabase.functions.invoke(
        'visit-photos',
        body: <String, dynamic>{'action': 'confirm', 'visit_id': visitId},
      );

      final confirmData = confirmResponse.data;
      if (confirmData is! Map || confirmData['status'] != 'attached') {
        throw const ServerException(
          'Server failed to confirm photo attachment.',
        );
      }
    });
  }

  /// Sends the signed-in employee's waiting visits, oldest first. A visit the
  /// server refuses for good is dropped; the first failure that may pass (no
  /// internet, a server error) ends the pass, and the next pass tries again.
  @override
  Future<void> syncPendingVisits() async {
    final employeeId =
        _currentEmployeeId?.call() ?? _supabase.auth.currentUser?.id;
    if (employeeId == null || _syncing) return;
    _syncing = true;
    try {
      for (final entry in await _queue.pendingFor(employeeId)) {
        if (_inFlight.contains(entry.visit.id)) continue;
        try {
          final outcome = await _deliver(entry);
          if (!outcome.done) break;
        } on AppException {
          // Refused for good and already forgotten: go on to the next one.
        }
      }
    } finally {
      _syncing = false;
    }
  }

  /// Puts the visit on the phone first. Throws when it cannot be kept there,
  /// so the employee is never told "saved" for a visit that exists nowhere.
  Future<VisitRecord> _saveOnPhone(VisitRecord visit) async {
    String? keptPhoto;
    try {
      final source = visit.localPhotoPath;
      if (source != null) keptPhoto = await _vault.keep(source, visit.id);
      final saved = VisitRecord(
        id: visit.id,
        sessionId: visit.sessionId,
        employeeId: visit.employeeId,
        storeName: visit.storeName,
        note: visit.note,
        latitude: visit.latitude,
        longitude: visit.longitude,
        accuracy: visit.accuracy,
        capturedAt: visit.capturedAt,
        localPhotoPath: keptPhoto,
      );
      await _queue.enqueue(saved);
      return saved;
    } on Object catch (e, st) {
      if (keptPhoto != null) await _vault.discard(keptPhoto);
      logFailure('VisitRepository: could not save visit on phone', e, st);
      throw const ServerException(
        'Could not save the visit on this phone. Check that it has free storage.',
      );
    }
  }

  /// Sends what is still unsent for one visit.
  ///
  /// Returns `done` when the server holds everything (the entry is then gone
  /// from the phone) and `rowSent` when at least the visit row is confirmed.
  /// A failure that may pass leaves the entry waiting and returns `done: false`.
  /// A refusal of the row for good removes the entry and is thrown.
  Future<({bool done, bool rowSent})> _deliver(PendingVisit entry) async {
    final visit = entry.visit;
    var rowSent = entry.rowSent;
    _inFlight.add(visit.id);
    try {
      if (!rowSent) {
        await _insertRow(visit);
        await _queue.markRowSent(visit.id);
        rowSent = true;
      }
      final photo = visit.localPhotoPath;
      if (photo != null) {
        try {
          await _sendPhoto(visit.id, photo);
        } on AppException catch (e) {
          // A photo the server will never take is dropped; the visit stays.
          if (e is! ValidationException && e is! ConflictException) rethrow;
          logFailure(
            'VisitRepository: photo dropped for ${visit.id}',
            e,
          );
        }
      }
      await _forget(visit);
      return (done: true, rowSent: true);
    } on AppException catch (e) {
      if (!rowSent &&
          (e is ValidationException || e is AccountBlockedException)) {
        await _forget(visit);
        rethrow;
      }
      return (done: false, rowSent: rowSent);
    } finally {
      _inFlight.remove(visit.id);
    }
  }

  Future<void> _insertRow(VisitRecord visit) {
    return _run('record visit', () async {
      try {
        await _supabase.from('visits').insert(visit.toInsertPayload());
      } on PostgrestException catch (e) {
        // The same visit sent twice (same id) is harmless.
        if (e.code != '23505') rethrow;
      }
    });
  }

  /// Removes the entry and the phone's copy of its photo.
  Future<void> _forget(VisitRecord visit) async {
    await _queue.remove(visit.id);
    final photo = visit.localPhotoPath;
    if (photo != null) await _vault.discard(photo);
  }

  Future<T> _run<T>(String action, Future<T> Function() body) async {
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
      if (network != null) throw network;
      logFailure('VisitRepository: could not $action', e, st);
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
        return const UnauthorizedRoleException(
          'Your session has expired. Sign in again.',
        );
      case 'forbidden':
        return const UnauthorizedRoleException(
          'Only the employee who made the visit may upload its photo.',
        );
      case 'visit_not_found':
        return const ValidationException('Visit not found.');
      case 'photo_already_attached':
        return const ConflictException(
          'A photo is already attached to this visit.',
        );
      case 'visit_too_old':
        return const ValidationException(
          'Visits older than 14 days cannot accept photo uploads.',
        );
      case 'photo_rejected':
        return const ValidationException(
          'Photo format or size was rejected by the server.',
        );
      default:
        return ServerException('Could not $action. Please try again.');
    }
  }
}
