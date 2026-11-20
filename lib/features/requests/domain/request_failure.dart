import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Why a request action failed, in plain words.
enum RequestFailure {
  outsideWindow('Requests can be made for today and the last 7 days only.'),
  invalidTimes('Duty off must be after duty on, and not in the future.'),
  alreadyHasDuty('You already have a duty on that day.'),
  alreadyRequested('You already have a request waiting for that day.'),
  photoRequired('Add a photo.'),
  messageRequired('Write a message.'),
  invalidDates('Pick dates from the last 7 days up to 90 days ahead.'),
  notCancellable('This request is already decided.'),
  alreadyDecided('Another admin already decided this request.'),
  photosNotReady('Photo upload is not set up yet. Tell the admin.'),
  photoUploadFailed(
    'The photo did not upload. Check the internet and try again.',
  ),
  noInternet('No internet. Try again.'),
  unknown('Something went wrong. Try again.');

  const RequestFailure(this.message);

  final String message;
}

class RequestException implements Exception {
  const RequestException(this.failure);

  final RequestFailure failure;

  @override
  String toString() => 'RequestException(${failure.name})';
}

RequestFailure mapRequestError(Object error) {
  if (error is RequestException) return error.failure;
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is AuthRetryableFetchException) {
    return RequestFailure.noInternet;
  }
  final String text = switch (error) {
    PostgrestException(:final String message) => message,
    FunctionException(:final Object? details) => '$details',
    _ => error.toString(),
  };
  if (error is! PostgrestException &&
      (text.contains('ClientException') || text.contains('SocketException'))) {
    return RequestFailure.noInternet;
  }
  const Map<String, RequestFailure> codes = <String, RequestFailure>{
    'outside_request_window': RequestFailure.outsideWindow,
    'invalid_times': RequestFailure.invalidTimes,
    'already_has_duty': RequestFailure.alreadyHasDuty,
    'already_requested': RequestFailure.alreadyRequested,
    'photo_required': RequestFailure.photoRequired,
    'invalid_photo': RequestFailure.photoRequired,
    'message_required': RequestFailure.messageRequired,
    'invalid_dates': RequestFailure.invalidDates,
    'request_not_cancellable': RequestFailure.notCancellable,
    'request_already_decided': RequestFailure.alreadyDecided,
    'photos_not_configured': RequestFailure.photosNotReady,
  };
  for (final MapEntry<String, RequestFailure> e in codes.entries) {
    if (text.contains(e.key)) return e.value;
  }
  return RequestFailure.unknown;
}
