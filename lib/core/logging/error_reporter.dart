import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_log.dart';

/// Sends one error to the server.
typedef ErrorSender = Future<void> Function(
  String where,
  String message,
  DateTime happenedAt,
);

/// Sends the errors and crashes the app catches to the server's app errors
/// list (L88), so a problem on an employee's phone can be seen without the
/// phone.
///
/// Only where it failed and a short message go up, with long numbers (phone
/// numbers, coordinates, PINs), emails, links and tokens taken out. At most
/// [maxPerRun] errors a run, each different one once; the server keeps at
/// most 200 a person a day. Nothing is sent when nobody is signed in, and an
/// error that cannot be sent is dropped.
class ErrorReporter {
  ErrorReporter({
    required this._send,
    required this._isSignedIn,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ErrorSender _send;
  final bool Function() _isSignedIn;
  final DateTime Function() _now;

  static const int maxPerRun = 20;
  static const int maxMessageLength = 300;
  static const Duration sendTimeout = Duration(seconds: 10);

  final Set<String> _seen = <String>{};
  int _sent = 0;

  /// Makes [AppLog.failure] report through this.
  void install() => AppLog.reporter = report;

  /// Reports one failure. Returns the send, for tests; callers do not wait.
  Future<void> report(String where, Object error) async {
    if (_sent >= maxPerRun || !_isSignedIn()) return;
    final String message = clean('$error');
    if (!_seen.add('$where|$message')) return;
    _sent++;
    try {
      await _send(where, message, _now()).timeout(sendTimeout);
    } on Object catch (e) {
      // Never through AppLog: a failed send must not report itself.
      debugPrint('[error-report] not sent: ${e.runtimeType}');
    }
  }

  static final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
  static final RegExp _link = RegExp(r'https?://\S+');
  static final RegExp _token = RegExp(r'[A-Za-z0-9_\-]{32,}');
  static final RegExp _digits = RegExp(r'\d{6,}');
  static final RegExp _space = RegExp(r'\s+');

  /// The message without personal details, on one line, cut to
  /// [maxMessageLength].
  static String clean(String message) {
    final String out = message
        .replaceAll(_link, '[link]')
        .replaceAll(_email, '[email]')
        .replaceAll(_token, '[token]')
        .replaceAll(_digits, '[number]')
        .replaceAll(_space, ' ')
        .trim();
    final String text = out.isEmpty ? '(no message)' : out;
    return text.length <= maxMessageLength
        ? text
        : '${text.substring(0, maxMessageLength - 3)}...';
  }
}
