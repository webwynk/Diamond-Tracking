import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/photo_upload.dart';

/// Why a request action failed, in plain words.
enum RequestFailure {
  outsideWindow('Requests can be made for today and the last 7 days only.'),
  invalidTimes('Duty off must be after duty on, and not in the future.'),
  alreadyHasDuty('You already have a duty on that day.'),
  alreadyRequested('You already have a request waiting for that day.'),
  photoRequired('Add a photo.'),
  messageRequired('Write a message.'),
  invalidDates('Pick up to 31 days, from today up to 90 days ahead.'),
  leaveFromToday('Leave can be asked for today or later, not past days.'),
  sickLeaveOnly('Only sick leave can be asked for. Update the app.'),
  notCancellable('This request is already decided.'),
  alreadyDecided('Another admin already decided this request.'),
  dayHasDuty(
    'This person already has a recorded duty that day. '
    'Reject this request instead.',
  ),
  noteTooLong('Note too long (300 characters max).'),
  dutyRunning('This duty is still running. Change it after duty off.'),
  futureDay('A day in the future cannot be changed.'),
  photosNotReady('Photo upload is not set up yet. Tell the admin.'),
  photoLimit('Photo limit for today reached (60 photos). Try again tomorrow.'),
  photoUploadFailed(
    'The photo did not upload. Check the internet and try again.',
  ),
  signedInElsewhere(
    'Your account is logged in on another phone. Log out there first, or '
    'ask your admin to release the phone.',
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
  if (error is PhotoUploadFailed) return RequestFailure.photoUploadFailed;
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
    'leave_from_today': RequestFailure.leaveFromToday,
    // Also matches the database checks requests_sick_leave_only and
    // duty_days_sick_leave_only (an old app sending casual leave).
    'sick_leave_only': RequestFailure.sickLeaveOnly,
    'request_not_cancellable': RequestFailure.notCancellable,
    'request_already_decided': RequestFailure.alreadyDecided,
    'day_has_duty': RequestFailure.dayHasDuty,
    'note_too_long': RequestFailure.noteTooLong,
    'duty_running': RequestFailure.dutyRunning,
    'future_day': RequestFailure.futureDay,
    'photos_not_configured': RequestFailure.photosNotReady,
    'photo_limit': RequestFailure.photoLimit,
    'signed_in_elsewhere': RequestFailure.signedInElsewhere,
  };
  for (final MapEntry<String, RequestFailure> e in codes.entries) {
    if (text.contains(e.key)) return e.value;
  }
  return RequestFailure.unknown;
}
