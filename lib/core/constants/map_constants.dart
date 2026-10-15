/// Configuration constants for MapLibre and OpenFreeMap integration.
///
/// Source of truth: docs/07-MAPLIBRE-BEST-PRACTICES.md.
/// Zero API keys, zero token dependencies, and zero vendor use-case tracking restrictions.
abstract final class MapConstants {
  const MapConstants._();

  /// Primary vector tile style URL from OpenFreeMap.
  static const String defaultStyle =
      'https://tiles.openfreemap.org/styles/liberty';

  /// Bright street map alternative style.
  static const String brightStyle =
      'https://tiles.openfreemap.org/styles/bright';

  /// Minimalist grey style for data-heavy views.
  static const String positronStyle =
      'https://tiles.openfreemap.org/styles/positron';

  /// Default focal center (Sinnar / Baramati agricultural sector, Maharashtra).
  static const double defaultLatitude = 19.8540;
  static const double defaultLongitude = 73.8567;
  static const double defaultZoom = 14.5;

  /// Mandatory legal attribution per OpenStreetMap and OpenFreeMap licences.
  static const String attribution = '© OpenFreeMap © OpenStreetMap';
}
