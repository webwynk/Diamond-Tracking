import 'dart:async';

import 'package:flutter/foundation.dart';

/// One place for diagnostic logging.
///
/// Never log tokens, passwords, PINs, exact coordinates of a person, or photo
/// links. Log what failed and where, not whose data it was.
abstract final class AppLog {
  const AppLog._();

  /// Lets tests see every failure.
  static void Function(String where, Object error)? onFailure;

  /// Sends failures to the server (see ErrorReporter). Set at startup.
  static Future<void> Function(String where, Object error)? reporter;

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[info] $message');
    }
  }

  static void failure(String where, Object error, [StackTrace? stack]) {
    onFailure?.call(where, error);
    final Future<void> Function(String, Object)? report = reporter;
    if (report != null) unawaited(report(where, error));
    debugPrint('[failure] $where: $error');
    if (kDebugMode && stack != null) {
      debugPrint(stack.toString());
    }
  }
}
