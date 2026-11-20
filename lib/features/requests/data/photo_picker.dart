import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum PhotoFrom { camera, gallery }

/// Picks a photo, already shrunk to about 1600 px and JPEG quality 75
/// (about 200 KB), so uploads stay quick on mobile data.
abstract interface class PhotoPicker {
  Future<Uint8List?> pick(PhotoFrom from);
}

class ImagePhotoPicker implements PhotoPicker {
  ImagePhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pick(PhotoFrom from) async {
    final XFile? file = await _picker.pickImage(
      source: from == PhotoFrom.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
      requestFullMetadata: false,
    );
    return file?.readAsBytes();
  }
}
