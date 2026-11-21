import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The phone's battery level for the duty card, or null when it cannot be
/// read. Home refreshes it every few minutes.
final FutureProvider<int?> phoneBatteryProvider =
    FutureProvider.autoDispose<int?>((Ref ref) async {
      try {
        return await Battery().batteryLevel;
      } on Object {
        return null;
      }
    });
