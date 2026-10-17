import 'package:image_picker/image_picker.dart';

/// Service abstraction for taking in-situ photos.
///
/// Adheres to PRD F10: "Camera-only capture. The gallery must be unreachable."
abstract class CameraService {
  /// Captures an in-situ photo via device camera.
  /// Returns local file path, or null if cancelled/denied.
  Future<String?> capturePhoto({
    double maxWidth = 1280,
    double maxHeight = 1280,
    int imageQuality = 85,
  });
}

/// Production implementation using [ImagePicker] strictly restricted to [ImageSource.camera].
class DeviceCameraService implements CameraService {
  DeviceCameraService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> capturePhoto({
    double maxWidth = 1280,
    double maxHeight = 1280,
    int imageQuality = 85,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        requestFullMetadata: true,
      );
      return file?.path;
    } catch (_) {
      return null;
    }
  }
}
