import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/camera_service.dart';
import '../../../../data/repositories/local_visit_repository.dart';
import '../../../../domain/entities/visit_record.dart';
import '../../../../domain/repositories/visit_repository.dart';

/// Provider for the global [CameraService] dependency.
final cameraServiceProvider = Provider<CameraService>((ref) {
  return DeviceCameraService();
});

/// Provider for the global [VisitRepository] dependency.
final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  return LocalVisitRepository();
});

/// State for the visit capture bottom sheet.
@immutable
class VisitCaptureState {
  const VisitCaptureState({
    this.placeName = 'Shivpuri Farm',
    this.placeId,
    this.arrivalTime = '2:14 PM',
    this.distanceMeters = 500.0,
    this.latitude = 19.9975,
    this.longitude = 73.7898,
    this.photoPath,
    this.geotagTimestamp = '12 Oct 2026, 2:15 PM',
    this.geotagCoordinates = '19.9975° N, 73.7898° E',
    this.note = 'Met owner, discussed kharif seed order.',
    this.photoSkipped = false,
    this.photoSkipReason,
    this.isSaving = false,
    this.isSaved = false,
    this.errorMessage,
  });

  final String placeName;
  final String? placeId;
  final String arrivalTime;
  final double? distanceMeters;
  final double latitude;
  final double longitude;
  final String? photoPath;
  final String geotagTimestamp;
  final String geotagCoordinates;
  final String note;
  final bool photoSkipped;
  final String? photoSkipReason;
  final bool isSaving;
  final bool isSaved;
  final String? errorMessage;

  VisitCaptureState copyWith({
    String? placeName,
    String? placeId,
    String? arrivalTime,
    double? distanceMeters,
    double? latitude,
    double? longitude,
    String? photoPath,
    String? geotagTimestamp,
    String? geotagCoordinates,
    String? note,
    bool? photoSkipped,
    String? photoSkipReason,
    bool? isSaving,
    bool? isSaved,
    String? errorMessage,
  }) {
    return VisitCaptureState(
      placeName: placeName ?? this.placeName,
      placeId: placeId ?? this.placeId,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photoPath: photoPath ?? this.photoPath,
      geotagTimestamp: geotagTimestamp ?? this.geotagTimestamp,
      geotagCoordinates: geotagCoordinates ?? this.geotagCoordinates,
      note: note ?? this.note,
      photoSkipped: photoSkipped ?? this.photoSkipped,
      photoSkipReason: photoSkipReason ?? this.photoSkipReason,
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
/// and visit submission adhering to PRD F10 & BR-12.
class VisitCaptureNotifier extends Notifier<VisitCaptureState> {
  late final CameraService _cameraService;
  late final VisitRepository _visitRepository;

  @override
  VisitCaptureState build() {
    _cameraService = ref.watch(cameraServiceProvider);
    _visitRepository = ref.watch(visitRepositoryProvider);

    return const VisitCaptureState();
  }

  /// Initializes the visit capture state with place and GPS context.
  void initVisit({
    required String placeName,
    String? placeId,
    required double latitude,
    required double longitude,
    double? distanceMeters,
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
      placeName: placeName,
      placeId: placeId,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters,
      arrivalTime: formattedTime,
      geotagTimestamp: formattedDate,
      geotagCoordinates: formattedCoords,
      note: initialNote ?? state.note,
      photoSkipped: false,
      photoSkipReason: null,
      isSaved: false,
      isSaving: false,
    );
  }

  /// Captures an in-situ photo using the device camera.
  Future<void> takePhoto() async {
    final path = await _cameraService.capturePhoto();
    if (path != null) {
      final now = DateTime.now();
      final formattedTime =
          '${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
      final formattedDate =
          '${now.day} ${_monthName(now.month)} ${now.year}, $formattedTime';

      state = state.copyWith(
        photoPath: path,
        photoSkipped: false,
        photoSkipReason: null,
        geotagTimestamp: formattedDate,
      );
    }
  }

  /// Updates the visit note text (capped at 200 characters).
  void updateNote(String text) {
    if (text.length <= 200) {
      state = state.copyWith(note: text);
    }
  }

  /// Skips the photo requirement by recording a valid reason per BR-12.
  void skipPhoto(String reason) {
    state = state.copyWith(
      photoSkipped: true,
      photoSkipReason: reason.trim(),
      photoPath: null,
    );
  }

  /// Saves the visit record to the repository.
  Future<bool> saveVisit({
    required String dutySessionId,
    required String employeeId,
  }) async {
    if (state.isSaving) return false;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final record = VisitRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        dutySessionId: dutySessionId,
        employeeId: employeeId,
        placeName: state.placeName,
        placeId: state.placeId,
        latitude: state.latitude,
        longitude: state.longitude,
        distanceMeters: state.distanceMeters,
        photoPath: state.photoPath,
        photoSkipped: state.photoSkipped,
        photoSkipReason: state.photoSkipReason,
        notes: state.note.isEmpty ? null : state.note,
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}
