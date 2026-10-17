import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/errors/app_exceptions.dart';

/// Returns a [NetworkException] when [error] means the request never reached
/// the server (offline, DNS failure, dropped connection, timeout), else null.
///
/// Repositories use it first so "no internet" is reported the same way
/// everywhere and is never confused with a server rejection.
NetworkException? asNetworkFailure(Object error) {
  if (error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException) {
    return const NetworkException();
  }
  return null;
}
