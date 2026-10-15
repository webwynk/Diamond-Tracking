import 'package:flutter/foundation.dart';

/// State representation for device onboarding prerequisites (Screen 05).
@immutable
class PermissionSetupState {
  final bool isLocationGranted;
  final bool isBackgroundGranted;
  final bool isBatteryOptimizationIgnored;
  final bool isLoading;

  const PermissionSetupState({
    this.isLocationGranted = false,
    this.isBackgroundGranted = false,
    this.isBatteryOptimizationIgnored = false,
    this.isLoading = false,
  });

  /// True when all 3 mandatory device prerequisites are satisfied.
  bool get allRequirementsSatisfied =>
      isLocationGranted && isBackgroundGranted && isBatteryOptimizationIgnored;

  PermissionSetupState copyWith({
    bool? isLocationGranted,
    bool? isBackgroundGranted,
    bool? isBatteryOptimizationIgnored,
    bool? isLoading,
  }) {
    return PermissionSetupState(
      isLocationGranted: isLocationGranted ?? this.isLocationGranted,
      isBackgroundGranted: isBackgroundGranted ?? this.isBackgroundGranted,
      isBatteryOptimizationIgnored:
          isBatteryOptimizationIgnored ?? this.isBatteryOptimizationIgnored,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionSetupState &&
          runtimeType == other.runtimeType &&
          isLocationGranted == other.isLocationGranted &&
          isBackgroundGranted == other.isBackgroundGranted &&
          isBatteryOptimizationIgnored == other.isBatteryOptimizationIgnored &&
          isLoading == other.isLoading;

  @override
  int get hashCode =>
      isLocationGranted.hashCode ^
      isBackgroundGranted.hashCode ^
      isBatteryOptimizationIgnored.hashCode ^
      isLoading.hashCode;
}
