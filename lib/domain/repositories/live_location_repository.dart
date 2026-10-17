import '../entities/live_position.dart';

/// One thing that happened to the live map while it was open.
sealed class LiveLocationEvent {
  const LiveLocationEvent();
}

/// An employee's position was created or moved.
class LivePositionChanged extends LiveLocationEvent {
  const LivePositionChanged(this.position);

  final LivePosition position;
}

/// An employee went off duty (their row was removed).
class LivePositionRemoved extends LiveLocationEvent {
  const LivePositionRemoved(this.employeeId);

  final String employeeId;
}

/// The live connection came up or went down. Coming up means events may have
/// been missed, so the listener must reload the full list.
class LiveConnectionChanged extends LiveLocationEvent {
  const LiveConnectionChanged({required this.connected});

  final bool connected;
}

/// Contract for reading where on-duty employees are, for the admin live map.
///
/// Implemented by `SupabaseLiveLocationRepository`. Every method returns real
/// server data or throws an `AppException`; nothing is invented when the
/// backend cannot be reached.
abstract class LiveLocationRepository {
  /// Everyone who is on duty right now, with their latest position.
  ///
  /// Throws [NetworkException] when offline, [UnauthorizedRoleException] when
  /// the caller may not read it, or [ServerException] otherwise.
  Future<List<LivePosition>> fetchAll();

  /// The server's clock (UTC), so "last seen" does not depend on the admin's
  /// phone clock being right.
  Future<DateTime> getServerTime();

  /// Changes as they happen. Listening opens the connection; cancelling closes
  /// it. The stream never errors: a connection problem arrives as a
  /// [LiveConnectionChanged] and the client reconnects by itself.
  Stream<LiveLocationEvent> watch();
}
