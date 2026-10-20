import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Keeps a visit's photo safe on the phone until the server has it.
///
/// The camera leaves its picture in a cache folder that Android may clear at
/// any time. A photo that is waiting to be sent is therefore copied into the
/// app's private storage, which only the app (or an uninstall) can empty.
abstract class VisitPhotoVault {
  /// Copies the photo at [sourcePath] into the vault and returns the copy's
  /// path, or null when [sourcePath] no longer exists. Throws when the copy
  /// itself fails (for example, the phone's storage is full): the caller must
  /// then tell the employee the visit was not saved.
  Future<String?> keep(String sourcePath, String visitId);

  /// Deletes a photo kept earlier. Never throws: a file that is already gone is
  /// the result wanted.
  Future<void> discard(String path);
}

/// The real vault: `<app documents>/visit_photos/<visit id>.jpg`.
class DeviceVisitPhotoVault implements VisitPhotoVault {
  @override
  Future<String?> keep(String sourcePath, String visitId) async {
    final source = File(sourcePath);
    if (!source.existsSync()) return null;

    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory(
      '${documents.path}${Platform.pathSeparator}visit_photos',
    );
    await folder.create(recursive: true);
    final target = '${folder.path}${Platform.pathSeparator}$visitId.jpg';
    await source.copy(target);
    return target;
  }

  @override
  Future<void> discard(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Nothing useful to do: the file is private to the app.
    }
  }
}
