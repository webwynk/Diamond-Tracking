import 'package:flutter/foundation.dart';

/// The one way the app logs a failure it has caught.
///
/// An error's text can carry what it was working on: a database exception can
/// include row details, a network exception a host name. `debugPrint` is not
/// removed from release builds, so the text of an error must not reach the
/// phone's log there (docs/05 section 7, docs/08 section 9).
///
/// Release builds log where it happened and the error's type. Debug builds log
/// the whole error and the stack trace, because that is what a developer needs.
void logFailure(String where, Object error, [StackTrace? stack]) {
  onFailureLogged?.call(where, error);
  debugPrint(failureMessage(where, error, stack));
}

/// Told about every failure that is logged. Only tests set it (test/flutter_test_config.dart),
/// to notice a test that reaches a real server client by mistake. Never set in
/// the app.
@visibleForTesting
void Function(String where, Object error)? onFailureLogged;

/// The line [logFailure] prints. Separate so a test can check both modes.
@visibleForTesting
String failureMessage(
  String where,
  Object error,
  StackTrace? stack, {
  bool release = kReleaseMode,
}) {
  if (release) return '$where (${error.runtimeType})';
  return stack == null ? '$where: $error' : '$where: $error\n$stack';
}
