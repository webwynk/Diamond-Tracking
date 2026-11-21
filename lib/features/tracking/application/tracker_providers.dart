import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock_providers.dart';
import 'tracker_control.dart';

/// The tracker. Overridden with a fake in tests.
final Provider<TrackerControl> trackerControlProvider =
    Provider<TrackerControl>(
      (Ref ref) => ForegroundTrackerControl(
        now: () => ref.read(serverClockProvider).now(),
      ),
    );
