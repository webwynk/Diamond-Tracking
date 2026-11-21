/// One GPS fix from the phone, before filtering.
class TrackFix {
  const TrackFix({
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    this.mocked = false,
  });

  /// When the fix was taken, by the phone's clock (UTC).
  final DateTime time;
  final double latitude;
  final double longitude;

  /// Horizontal accuracy in metres (68% confidence).
  final double accuracyM;

  /// Android says the fix came from a fake-location ("mock location") app.
  final bool mocked;
}
