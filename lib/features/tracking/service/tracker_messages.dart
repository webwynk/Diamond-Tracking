/// Messages between the app and the tracker service. Only strings and maps
/// can cross between the two engines.
abstract final class TrackerMessages {
  const TrackerMessages._();

  /// App to service: the session changed (duty off, resume), check now.
  static const String refresh = 'refresh';

  /// Service to app: status changed (points uploaded, GPS problem).
  static const String status = 'status';

  /// Service to app: the service stopped itself.
  static const String stopped = 'stopped';

  /// Service to app: a battery warning.
  static Map<String, Object> battery(int level) => <String, Object>{
    'battery': level,
  };

  /// The battery level in a message from the service, or null.
  static int? batteryLevelOf(Object data) {
    if (data is Map && data['battery'] is int) return data['battery'] as int;
    return null;
  }
}
