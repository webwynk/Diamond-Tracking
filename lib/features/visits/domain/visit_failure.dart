import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../requests/data/photo_upload.dart';

/// Why adding a visit failed, in plain words.
enum VisitFailure {
  notOnDuty('Visits can be added only while you are on duty.'),
  storeNameRequired('Write the store name.'),
  photoRequired('Add a photo.'),
  noLocation(
    'Your location was not found. Turn on location, step outside if you can, '
    'and try again. Or pick the photo from the gallery.',
  ),
  noteTooLong('The note is too long.'),
  photosNotReady('Photo upload is not set up yet. Tell the admin.'),
  photoUploadFailed(
    'The photo did not upload. Check the internet and try again.',
  ),
  signedInElsewhere(
    'Your account is logged in on another phone. Log out there first, or '
    'ask your admin to release the phone.',
  ),
  noInternet('No internet. Try again.'),
  unknown('Something went wrong. Try again.');

  const VisitFailure(this.message);

  final String message;
}

class VisitException implements Exception {
  const VisitException(this.failure);

  final VisitFailure failure;

  @override
  String toString() => 'VisitException(${failure.name})';
}

VisitFailure mapVisitError(Object error) {
  if (error is VisitException) return error.failure;
  if (error is PhotoUploadFailed) return VisitFailure.photoUploadFailed;
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is AuthRetryableFetchException) {
    return VisitFailure.noInternet;
  }
  final String text = switch (error) {
    PostgrestException(:final String message) => message,
    FunctionException(:final Object? details) => '$details',
    _ => error.toString(),
  };
  if (error is! PostgrestException &&
      (text.contains('ClientException') || text.contains('SocketException'))) {
    return VisitFailure.noInternet;
  }
  const Map<String, VisitFailure> codes = <String, VisitFailure>{
    'not_on_duty': VisitFailure.notOnDuty,
    'store_name_required': VisitFailure.storeNameRequired,
    'photo_required': VisitFailure.photoRequired,
    'location_required': VisitFailure.noLocation,
    'note_too_long': VisitFailure.noteTooLong,
    'photos_not_configured': VisitFailure.photosNotReady,
    'signed_in_elsewhere': VisitFailure.signedInElsewhere,
  };
  for (final MapEntry<String, VisitFailure> e in codes.entries) {
    if (text.contains(e.key)) return e.value;
  }
  return VisitFailure.unknown;
}
