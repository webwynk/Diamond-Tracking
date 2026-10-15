import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/permission_service.dart';
import 'permission_state.dart';

/// Provider for the [PermissionService] dependency.
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return const DevicePermissionService();
});

/// Riverpod provider for managing Screen 05 permission and battery optimization state.
final permissionControllerProvider =
    NotifierProvider<PermissionNotifier, PermissionSetupState>(
      PermissionNotifier.new,
    );

/// Notifier managing device permissions, background location, and battery optimization state.
class PermissionNotifier extends Notifier<PermissionSetupState> {
  late final PermissionService _service;

  @override
  PermissionSetupState build() {
    _service = ref.watch(permissionServiceProvider);
    // Asynchronously populate the actual OS permission state.
    Future.microtask(refresh);
    return const PermissionSetupState(isLoading: true);
  }

  /// Inspects current OS status across location, background location, and battery optimization.
  Future<void> refresh() async {
    try {
      final location = await _service.isLocationGranted();
      final background = await _service.isBackgroundLocationGranted();
      final battery = await _service.isBatteryOptimizationIgnored();

      if (!ref.mounted) return;

      state = state.copyWith(
        isLocationGranted: location,
        isBackgroundGranted: background,
        isBatteryOptimizationIgnored: battery,
        isLoading: false,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  /// Requests foreground location access.
  Future<bool> requestLocation() async {
    try {
      final granted = await _service.requestLocation();
      await refresh();
      return granted;
    } catch (_) {
      await refresh();
      return false;
    }
  }

  /// Requests background location ("Allow all the time").
  Future<bool> requestBackgroundLocation() async {
    try {
      final granted = await _service.requestBackgroundLocation();
      await refresh();
      return granted;
    } catch (_) {
      await refresh();
      return false;
    }
  }

  /// Requests the system battery optimization exemption dialog.
  Future<bool> requestBatteryOptimization() async {
    try {
      final ignored = await _service.requestIgnoreBatteryOptimizations();
      await refresh();
      return ignored;
    } catch (_) {
      await refresh();
      return false;
    }
  }

  /// Deep links to application settings in OS.
  Future<bool> openAppSettings() async {
    try {
      return await _service.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
