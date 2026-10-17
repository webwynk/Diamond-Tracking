import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Whether the native MapLibre renderer can run on this platform.
///
/// MapLibre needs an Android or iOS OpenGL surface. In widget tests and on
/// desktop or web there is none, so screens show a plain placeholder instead.
abstract final class MapSupport {
  const MapSupport._();

  static bool get isNativeMapAvailable {
    if (kIsWeb) return false;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
