import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tracker_control.dart';

/// The tracker. Overridden with a fake in tests.
final Provider<TrackerControl> trackerControlProvider =
    Provider<TrackerControl>((Ref ref) => ForegroundTrackerControl());
