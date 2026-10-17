import 'package:flutter/foundation.dart';

/// The server's verdict on a batch of GPS points (`ingest_location_points`).
///
/// A point the server did not mention is in neither set: the phone must keep
/// it and try again, never assume it was stored.
@immutable
class PointIngestResult {
  const PointIngestResult({
    this.confirmedIds = const <String>{},
    this.rejected = const <String, String>{},
  });

  /// Points now safely on the server: stored just now, or already there from an
  /// earlier attempt whose answer was lost. Safe to delete from the phone.
  final Set<String> confirmedIds;

  /// Points the server will never accept, with its reason (for example
  /// `point_outside_session`). Safe to discard.
  final Map<String, String> rejected;
}
