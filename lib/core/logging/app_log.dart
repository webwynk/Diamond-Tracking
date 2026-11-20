import 'package:flutter/foundation.dart';

/// One place for diagnostic logging.
///
/// Never log tokens, passwords, PINs, exact coordinates of a person, or photo
/// links. Log what failed and where, not whose data it was.
abstract final class AppLog {
  const AppLog._();

  /// Lets tests (and later a crash reporter) see every failure.
  static void Function(String where, Object error)? onFailure;

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[info] $message');
    }
  }

  static void failure(String where, Object error, [StackTrace? stack]) {
    onFailure?.call(where, error);
    debugPrint('[failure] $where: $error');
    if (kDebugMode && stack != null) {
      debugPrint(stack.toString());
    }
  }
}
