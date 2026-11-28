import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock_providers.dart';
import '../data/phone_setup.dart';
import '../domain/tracker_status.dart';
import 'tracker_control.dart';

/// The tracker. Overridden with a fake in tests.
final Provider<TrackerControl> trackerControlProvider =
    Provider<TrackerControl>(
      (Ref ref) => ForegroundTrackerControl(
        now: () => ref.read(serverClockProvider).now(),
      ),
    );

/// The tracker service's latest status while the app is open (points
/// waiting, no internet, recording stopped). Empty until the first check.
final StreamProvider<TrackerStatus> trackerStatusProvider =
    StreamProvider<TrackerStatus>(
      (Ref ref) => ref.watch(trackerControlProvider).statusUpdates,
    );

/// The phone maker's own battery settings. Overridden in tests.
final Provider<PhoneSetup> phoneSetupProvider = Provider<PhoneSetup>(
  (Ref ref) => DevicePhoneSetup(),
);
