import 'package:permission_handler/permission_handler.dart' as ph;

/// Contract for managing runtime OS permissions and battery optimization checks.
///
/// Abstracted so presentation logic and tests can run reliably without being
/// coupled to underlying Android platform channel calls.
abstract class PermissionService {
  /// Whether the phone's location service (GPS switch) is turned on.
  Future<bool> isLocationServiceEnabled();

  /// Whether foreground fine/coarse location is granted.
  Future<bool> isLocationGranted();

  /// Whether background location ("Allow all the time") is granted.
  Future<bool> isBackgroundLocationGranted();

  /// Whether battery saver restrictions/optimizations are disabled for this app.
  Future<bool> isBatteryOptimizationIgnored();

  /// Requests foreground location access.
  Future<bool> requestLocation();

  /// Requests background location access ("Allow all the time").
  Future<bool> requestBackgroundLocation();

  /// Requests the OS dialog to exempt the app from battery optimizations.
  Future<bool> requestIgnoreBatteryOptimizations();

  /// Deep-links to the application settings in the Android OS.
  Future<bool> openAppSettings();
}

/// Production implementation of [PermissionService] backed by `permission_handler`.
class DevicePermissionService implements PermissionService {
  const DevicePermissionService();

  @override
  Future<bool> isLocationServiceEnabled() async {
    final status = await ph.Permission.location.serviceStatus;
    return status.isEnabled;
  }

  @override
  Future<bool> isLocationGranted() async {
    final status = await ph.Permission.location.status;
    return status.isGranted;
  }

  @override
  Future<bool> isBackgroundLocationGranted() async {
    final status = await ph.Permission.locationAlways.status;
    return status.isGranted;
  }

  @override
  Future<bool> isBatteryOptimizationIgnored() async {
    final status = await ph.Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  @override
  Future<bool> requestLocation() async {
    final status = await ph.Permission.location.request();
    return status.isGranted;
  }

  @override
  Future<bool> requestBackgroundLocation() async {
    final status = await ph.Permission.locationAlways.request();
    return status.isGranted;
  }

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async {
    final status = await ph.Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  @override
  Future<bool> openAppSettings() async {
    return ph.openAppSettings();
  }
}
