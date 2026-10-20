import 'package:diamond_tracking/core/config/env.dart';

/// Configuration constants for MapLibre, MapTiler, and OpenFreeMap integration.
///
/// Source of truth: docs/07-MAPLIBRE-BEST-PRACTICES.md.
/// Primary provider is MapTiler when [Env.maptilerApiKey] is configured in `env.json`.
/// Automatically falls back to OpenFreeMap with zero dependencies when absent.
abstract final class MapConstants {
  const MapConstants._();

  /// Primary vector tile style URL.
  ///
  /// Uses MapTiler Streets v2 if [Env.maptilerApiKey] is set; falls back to OpenFreeMap Liberty.
  static String get defaultStyle => Env.maptilerApiKey.isNotEmpty
      ? 'https://api.maptiler.com/maps/streets-v2/style.json?key=${Env.maptilerApiKey}'
      : 'https://tiles.openfreemap.org/styles/liberty';

  /// Bright street/outdoor map alternative style.
  ///
  /// Uses MapTiler Outdoor v2 (rich terrain for agricultural sectors) if key is set;
  /// falls back to OpenFreeMap Bright.
  static String get brightStyle => Env.maptilerApiKey.isNotEmpty
      ? 'https://api.maptiler.com/maps/outdoor-v2/style.json?key=${Env.maptilerApiKey}'
      : 'https://tiles.openfreemap.org/styles/bright';

  /// Default focal center (Sinnar / Baramati agricultural sector, Maharashtra).
  static const double defaultLatitude = 19.8540;
  static const double defaultLongitude = 73.8567;
  static const double defaultZoom = 14.5;

  /// Mandatory legal attribution per OpenStreetMap, MapTiler, and OpenFreeMap licences.
  static String get attribution => Env.maptilerApiKey.isNotEmpty
      ? '© MapTiler © OpenStreetMap contributors'
      : '© OpenFreeMap © OpenStreetMap';

  /// Active map tile provider name.
  static String get providerName =>
      Env.maptilerApiKey.isNotEmpty ? 'MapTiler' : 'OpenFreeMap';
}
