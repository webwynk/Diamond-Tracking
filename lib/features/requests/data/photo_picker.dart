import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum PhotoFrom { camera, gallery }

/// Picks a photo, already shrunk to at most 1280 px and JPEG quality 75
/// (about 150-250 KB), so uploads stay quick on mobile data. Cloudinary also
/// shrinks anything bigger to 1280 px when it arrives (L62).
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
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 75,
      requestFullMetadata: false,
    );
    return file?.readAsBytes();
  }
}
