import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:url_launcher/url_launcher.dart';

/// Opens a link in another app (Google Maps). Answers false when no app
/// could open it. Overridden in tests.
final Provider<Future<bool> Function(Uri)> openLinkProvider =
    Provider<Future<bool> Function(Uri)>(
      (Ref ref) =>
          (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
    );

/// A Google Maps link that drops a pin at [lat], [lng].
Uri mapsLink(double lat, double lng) =>
    Uri.https('www.google.com', '/maps/search/', <String, String>{
      'api': '1',
      'query': '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
    });

/// Opens this app's page in the phone's settings (to allow the camera).
/// Overridden in tests.
final Provider<Future<bool> Function()> openAppSettingsProvider =
    Provider<Future<bool> Function()>((Ref ref) => Geolocator.openAppSettings);
