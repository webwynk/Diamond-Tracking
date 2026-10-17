import 'package:diamond_tracking/core/services/permission_service.dart';

/// Test-only [PermissionService] whose answers are set per test, so duty
/// tests never reach the Android permission channel.
class FakePermissionService implements PermissionService {
  FakePermissionService({
    this.locationEnabled = true,
    this.locationGranted = true,
    this.backgroundGranted = true,
    this.batteryIgnored = true,
  });

  bool locationEnabled;
  bool locationGranted;
  bool backgroundGranted;
  bool batteryIgnored;

  @override
  Future<bool> isLocationServiceEnabled() async => locationEnabled;

  @override
  Future<bool> isLocationGranted() async => locationGranted;

  @override
  Future<bool> isBackgroundLocationGranted() async => backgroundGranted;

  @override
  Future<bool> isBatteryOptimizationIgnored() async => batteryIgnored;

  @override
  Future<bool> requestLocation() async => locationGranted;

  @override
  Future<bool> requestBackgroundLocation() async => backgroundGranted;

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async => batteryIgnored;

  @override
  Future<bool> openAppSettings() async => true;
}
