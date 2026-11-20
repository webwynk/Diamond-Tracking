import 'dart:io';

import '../engine/tracker_engine.dart';

/// Reads uptime and the boot id from Linux's /proc, which every Android app
/// can read.
class ProcSystemInfo implements SystemInfo {
  const ProcSystemInfo();

  /// When uptime cannot be read, a restart cannot be told apart, so the
  /// break is recorded as "tracking stopped".
  static const Duration _unknown = Duration(days: 36500);

  @override
  Duration uptime() {
    try {
      final String first = File('/proc/uptime')
          .readAsStringSync()
          .trim()
          .split(' ')
          .first;
      return Duration(milliseconds: (double.parse(first) * 1000).round());
    } on Object {
      return _unknown;
    }
  }

  @override
  String? bootId() {
    try {
      final String id = File('/proc/sys/kernel/random/boot_id')
          .readAsStringSync()
          .trim();
      return id.isEmpty ? null : id;
    } on Object {
      return null;
    }
  }
}
