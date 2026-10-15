import 'package:flutter/foundation.dart';

import '../../../../domain/entities/duty_session.dart';

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
    this.satellitesAcquired = 9,
    this.errorMessage,
    this.disabledReason,
    this.isLoading = false,
  });

  final DutyStatus status;
  final DutySession? activeSession;
  final DutySession? yesterdaySession;
  final Duration elapsedDuration;
  final double distanceKm;
  final int visitsCount;
  final int queuedPointsCount;
  final int satellitesAcquired;
  final String? errorMessage;
  final String? disabledReason;
  final bool isLoading;

  bool get isOnDuty => status == DutyStatus.onDuty;
  bool get isOffDuty => status == DutyStatus.offDuty;
  bool get isDisabled => status == DutyStatus.disabledWindow;

  DutyScreenState copyWith({
    DutyStatus? status,
    DutySession? activeSession,
    DutySession? yesterdaySession,
    Duration? elapsedDuration,
    double? distanceKm,
    int? visitsCount,
    int? queuedPointsCount,
    int? satellitesAcquired,
    String? errorMessage,
    String? disabledReason,
    bool? isLoading,
  }) {
    return DutyScreenState(
      status: status ?? this.status,
      activeSession: activeSession ?? this.activeSession,
      yesterdaySession: yesterdaySession ?? this.yesterdaySession,
      elapsedDuration: elapsedDuration ?? this.elapsedDuration,
      distanceKm: distanceKm ?? this.distanceKm,
      visitsCount: visitsCount ?? this.visitsCount,
      queuedPointsCount: queuedPointsCount ?? this.queuedPointsCount,
      satellitesAcquired: satellitesAcquired ?? this.satellitesAcquired,
      errorMessage: errorMessage,
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
          isLoading == other.isLoading;

  @override
  int get hashCode =>
      status.hashCode ^
      activeSession.hashCode ^
      yesterdaySession.hashCode ^
      elapsedDuration.hashCode ^
      distanceKm.hashCode ^
      visitsCount.hashCode ^
      queuedPointsCount.hashCode ^
      isLoading.hashCode;
}
