import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The folder the app and the tracker service share (app-private storage).
Future<Directory> trackerDirectory() async {
  final Directory support = await getApplicationSupportDirectory();
  return Directory('${support.path}/tracker');
}
