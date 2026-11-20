import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Why a duty action failed, in words the employee understands.
enum DutyFailure {
  closed('Duty on is open from 5:00 AM to 8:30 AM only.'),
  onLeave('You are on leave today, so duty on is not allowed.'),
  alreadyOnDuty('You have already done duty on today.'),
  signedInElsewhere(
    'Your account is in use on another phone. Ask the admin to reset your '
    'password.',
  ),
  notOnDuty('Your duty is not on.'),
  alreadyEnded('This duty has already ended.'),
  noInternet('No internet. Duty on needs the internet; try again.'),
  clockNotSynced(
    'Could not check the time with the server. Check the internet and try '
    'again.',
  ),
  trackerFailed(
    'Could not start route recording. Close the app, open it again and try '
    'once more.',
  ),
  unknown('Something went wrong. Try again.');

  const DutyFailure(this.message);

  final String message;
}

class DutyException implements Exception {
  const DutyException(this.failure);

  final DutyFailure failure;

  @override
  String toString() => 'DutyException(${failure.name})';
}

/// Maps a server or network error to a [DutyFailure].
DutyFailure mapDutyError(Object error) {
  if (error is DutyException) return error.failure;
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is AuthRetryableFetchException) {
    return DutyFailure.noInternet;
  }
  final String text = error is PostgrestException
      ? error.message
      : error.toString();
  if (error is! PostgrestException &&
      (text.contains('ClientException') || text.contains('SocketException'))) {
    return DutyFailure.noInternet;
  }
  const Map<String, DutyFailure> codes = <String, DutyFailure>{
    'duty_on_closed': DutyFailure.closed,
    'on_leave_today': DutyFailure.onLeave,
    'already_on_duty_today': DutyFailure.alreadyOnDuty,
    'signed_in_elsewhere': DutyFailure.signedInElsewhere,
    'not_on_duty': DutyFailure.notOnDuty,
    'duty_already_ended': DutyFailure.alreadyEnded,
  };
  for (final MapEntry<String, DutyFailure> e in codes.entries) {
    if (text.contains(e.key)) return e.value;
  }
  return DutyFailure.unknown;
}
