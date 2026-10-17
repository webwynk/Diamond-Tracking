import 'package:flutter/foundation.dart';

import '../../../../domain/entities/duty_session.dart';
import '../../../../domain/entities/location_point.dart';

/// Presentation state for the employee duty status and hero toggle.
enum DutyStatus {
  /// Employee is off duty (Screen 06).
  offDuty,

  /// Actively starting duty, acquiring GPS, calibrating local telemetry.
  starting,

  /// Employee is currently on duty with active foreground tracking (Screen 07).
  onDuty,

  /// In the process of ending duty and uploading final telemetry.
  ending,

  /// Duty is disabled outside the 08:00–23:00 IST window (Screen 08).
  disabledWindow,
}

/// Why duty could not be started on this phone (PRD F3). Both can be fixed by
/// the employee, so the screen sends them to the matching fix.
enum DutyStartBlocker {
  /// Location, "Allow all the time" or the battery exemption is missing.
  permissionsMissing,

  /// The phone's location (GPS) switch is off.
  locationServicesOff,
}

/// What logging out would cost the employee right now.
@immutable
class SignOutCheck {
  const SignOutCheck({this.onDuty = false, this.unsyncedPoints = 0});

  /// Duty is on: tracking would stop and the admin would see a dead marker, so
  /// the employee must turn duty off first.
  final bool onDuty;

  /// Points recorded on this phone that have not reached the server. Signing
  /// out deletes them.
  final int unsyncedPoints;
}

/// Immutable state container for the Duty home screen.
@immutable
class DutyScreenState {
  const DutyScreenState({
    this.status = DutyStatus.offDuty,
    this.activeSession,
    this.yesterdaySession,
    this.elapsedDuration = Duration.zero,
    this.distanceKm = 0.0,
    this.visitsCount = 0,
    this.queuedPointsCount = 0,
    this.lastLocation,
    this.errorMessage,
    this.startBlocker,
    this.disabledReason,
    this.isLoading = false,
  });

  final DutyStatus status;
  final DutySession? activeSession;
  final DutySession? yesterdaySession;
  final Duration elapsedDuration;

  /// On-device estimate while on duty; the server's figure replaces it when
  /// duty ends (BR-8).
  final double distanceKm;
  final int visitsCount;
  final int queuedPointsCount;

  /// Most recent GPS sample from the tracking engine, null until one arrives.
  final LocationPoint? lastLocation;

  /// What went wrong with the last action, in words the employee can act on.
  /// Cleared by the next state change that does not set it.
  final String? errorMessage;

  /// Set when duty could not start for a reason the employee can fix.
  final DutyStartBlocker? startBlocker;
  final String? disabledReason;
  final bool isLoading;

  bool get isOnDuty => status == DutyStatus.onDuty;
  bool get isDisabled => status == DutyStatus.disabledWindow;

  DutyScreenState copyWith({
    DutyStatus? status,
    DutySession? activeSession,
    bool clearActiveSession = false,
    DutySession? yesterdaySession,
    Duration? elapsedDuration,
    double? distanceKm,
    int? visitsCount,
    int? queuedPointsCount,
    LocationPoint? lastLocation,
    bool clearLastLocation = false,
    String? errorMessage,
    DutyStartBlocker? startBlocker,
    String? disabledReason,
    bool? isLoading,
  }) {
    return DutyScreenState(
      status: status ?? this.status,
      activeSession: clearActiveSession
          ? null
          : (activeSession ?? this.activeSession),
      yesterdaySession: yesterdaySession ?? this.yesterdaySession,
      elapsedDuration: elapsedDuration ?? this.elapsedDuration,
      distanceKm: distanceKm ?? this.distanceKm,
      visitsCount: visitsCount ?? this.visitsCount,
      queuedPointsCount: queuedPointsCount ?? this.queuedPointsCount,
      lastLocation: clearLastLocation
          ? null
          : (lastLocation ?? this.lastLocation),
      errorMessage: errorMessage,
      startBlocker: startBlocker,
      disabledReason: disabledReason ?? this.disabledReason,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DutyScreenState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          activeSession == other.activeSession &&
          yesterdaySession == other.yesterdaySession &&
          elapsedDuration == other.elapsedDuration &&
          distanceKm == other.distanceKm &&
          visitsCount == other.visitsCount &&
          queuedPointsCount == other.queuedPointsCount &&
          lastLocation == other.lastLocation &&
          errorMessage == other.errorMessage &&
          startBlocker == other.startBlocker &&
          isLoading == other.isLoading;

  @override
  int get hashCode => Object.hash(
    status,
    activeSession,
    yesterdaySession,
    elapsedDuration,
    distanceKm,
    visitsCount,
    queuedPointsCount,
    lastLocation,
    errorMessage,
    startBlocker,
    isLoading,
  );
}
