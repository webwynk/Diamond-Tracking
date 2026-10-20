import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/camera_service.dart';
import '../../../../core/services/visit_sync_service.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../data/local/drift_visit_queue_store.dart';
import '../../../../data/repositories/supabase_visit_repository.dart';
import '../../../../domain/entities/visit_record.dart';
import '../../../../domain/repositories/visit_queue_store.dart';
import '../../../../domain/repositories/visit_repository.dart';
import '../../../duty/presentation/controllers/duty_controller.dart';

/// Provider for the global [CameraService] dependency.
final cameraServiceProvider = Provider<CameraService>((ref) {
  return DeviceCameraService();
});

/// The visits waiting on the phone to be sent.
final visitQueueStoreProvider = Provider<VisitQueueStore>((ref) {
  return DriftVisitQueueStore(ref.watch(trackingDatabaseProvider));
});

/// Provider for the global [VisitRepository] dependency.
final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  return SupabaseVisitRepository(ref.watch(visitQueueStoreProvider));
});

/// Retries sending waiting visits while the employee app is open.
final visitSyncServiceProvider = Provider<VisitSyncService>((ref) {
  final service = VisitSyncService(ref.watch(visitRepositoryProvider));
  ref.onDispose(service.stop);
  return service;
});

/// State for the visit capture bottom sheet.
@immutable
class VisitCaptureState {
  const VisitCaptureState({
    this.storeName = '',
    this.arrivalTime = '',
    this.latitude,
    this.longitude,
    this.accuracy,
    this.photoPath,
    this.geotagTimestamp = '',
    this.geotagCoordinates = '',
    this.note = '',
    this.isSaving = false,
    this.isSaved = false,
    this.errorMessage,
  });

  final String storeName;
  final String arrivalTime;

  /// Null until a GPS position is supplied by [VisitCaptureNotifier.initVisit].
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? photoPath;
  final String geotagTimestamp;
  final String geotagCoordinates;
  final String note;
  final bool isSaving;
  final bool isSaved;
  final String? errorMessage;

  /// [removePhoto] drops the photo; passing null for [photoPath] cannot, because
  /// null means "keep what there is".
  VisitCaptureState copyWith({
    String? storeName,
    String? arrivalTime,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? photoPath,
    String? geotagTimestamp,
    String? geotagCoordinates,
    String? note,
    bool? isSaving,
    bool? isSaved,
    String? errorMessage,
    bool removePhoto = false,
  }) {
    return VisitCaptureState(
      storeName: storeName ?? this.storeName,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      photoPath: removePhoto ? null : photoPath ?? this.photoPath,
      geotagTimestamp: geotagTimestamp ?? this.geotagTimestamp,
      geotagCoordinates: geotagCoordinates ?? this.geotagCoordinates,
      note: note ?? this.note,
      isSaving: isSaving ?? this.isSaving,
      isSaved: isSaved ?? this.isSaved,
      errorMessage: errorMessage,
    );
  }
}

/// Global provider for managing the visit capture flow.
final visitCaptureControllerProvider =
    NotifierProvider<VisitCaptureNotifier, VisitCaptureState>(
      VisitCaptureNotifier.new,
    );

/// Controller governing visit photo capture, geotag overlay, note updates,
/// and visit submission adhering strictly to PRD F10.
class VisitCaptureNotifier extends Notifier<VisitCaptureState> {
  late final CameraService _cameraService;
  late final VisitRepository _visitRepository;

  @override
  VisitCaptureState build() {
    _cameraService = ref.watch(cameraServiceProvider);
    _visitRepository = ref.watch(visitRepositoryProvider);

    return const VisitCaptureState();
  }

  /// Initializes the visit capture state with store name and GPS context.
  void initVisit({
    String? storeName,
    required double latitude,
    required double longitude,
    double? accuracy,
    String? initialNote,
  }) {
    final now = DateTime.now();
    final formattedTime =
        '${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    final formattedDate =
        '${now.day} ${_monthName(now.month)} ${now.year}, $formattedTime';
    final formattedCoords =
        '${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E';

    state = state.copyWith(
      storeName: storeName ?? '',
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      arrivalTime: formattedTime,
      geotagTimestamp: formattedDate,
      geotagCoordinates: formattedCoords,
      note: initialNote ?? '',
      isSaved: false,
      isSaving: false,
    );
  }

  /// Updates the optional store / shop name text (capped at 80 characters).
  void updateStoreName(String text) {
    if (text.length <= 80) {
      state = state.copyWith(storeName: text);
    }
  }

  /// Captures an in-situ photo strictly via the device camera.
  Future<void> takePhoto() async {
    final path = await _cameraService.capturePhoto();
    if (path != null) {
      final now = DateTime.now();
      final formattedTime =
          '${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
      final formattedDate =
          '${now.day} ${_monthName(now.month)} ${now.year}, $formattedTime';

      state = state.copyWith(photoPath: path, geotagTimestamp: formattedDate);
    }
  }

  /// Updates the visit note text (capped at 200 characters).
  void updateNote(String text) {
    if (text.length <= 200) {
      state = state.copyWith(note: text);
    }
  }

  /// Drops any captured photo so the visit is saved without one. Needs no
  /// reason and sets no flag (PRD F10, BR-12).
  void skipPhoto() {
    state = state.copyWith(removePhoto: true);
  }

  /// Saves the visit record to the repository.
  Future<bool> saveVisit({
    required String dutySessionId,
    required String employeeId,
  }) async {
    if (state.isSaving) return false;

    final latitude = state.latitude;
    final longitude = state.longitude;
    if (latitude == null || longitude == null) {
      state = state.copyWith(
        errorMessage:
            'No GPS position for this visit. Try again once GPS locks.',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final record = VisitRecord(
        id: IdGenerator.uuidV4(),
        sessionId: dutySessionId,
        employeeId: employeeId,
        storeName: state.storeName.trim().isEmpty
            ? null
            : state.storeName.trim(),
        note: state.note.trim().isEmpty ? null : state.note.trim(),
        latitude: latitude,
        longitude: longitude,
        accuracy: state.accuracy,
        localPhotoPath: state.photoPath,
        capturedAt: DateTime.now().toUtc(),
        synced: false,
      );

      await _visitRepository.recordVisit(record);

      state = state.copyWith(isSaving: false, isSaved: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save visit: ${e.toString()}',
      );
      return false;
    }
  }

  static String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}
