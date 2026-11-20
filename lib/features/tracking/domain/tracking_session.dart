/// What the tracker needs for one duty day.
///
/// Only the app writes it: at duty on (or resume) and at duty off. The
/// tracker service reads it. The pass lets the tracker upload this one day's
/// points without the sign-in session (see the phase 4 migration).
class TrackingSession {
  const TrackingSession({
    required this.dayId,
    required this.pass,
    required this.dutyOnAt,
    required this.autoOffAt,
    this.offAt,
    this.offConfirmed = false,
  });

  factory TrackingSession.fromJson(Map<String, Object?> json) {
    final Object? off = json['off_at'];
    return TrackingSession(
      dayId: json['day_id']! as int,
      pass: json['pass']! as String,
      dutyOnAt: DateTime.parse(json['duty_on_at']! as String).toUtc(),
      autoOffAt: DateTime.parse(json['auto_off_at']! as String).toUtc(),
      offAt: off is String ? DateTime.parse(off).toUtc() : null,
      offConfirmed: json['off_confirmed'] == true,
    );
  }

  final int dayId;
  final String pass;
  final DateTime dutyOnAt;

  /// 11:00 PM IST on the duty day: the tracker stops recording then.
  final DateTime autoOffAt;

  /// When duty off was pressed on the phone, or null while on duty.
  final DateTime? offAt;

  /// The server already has the duty off. When false (pressed offline), the
  /// tracker sends it once the internet is back.
  final bool offConfirmed;

  bool get isOff => offAt != null;

  /// Whether the tracker should be recording at [now].
  bool isActiveAt(DateTime now) => offAt == null && now.isBefore(autoOffAt);

  TrackingSession withDutyOff(DateTime at, {required bool confirmed}) =>
      TrackingSession(
        dayId: dayId,
        pass: pass,
        dutyOnAt: dutyOnAt,
        autoOffAt: autoOffAt,
        offAt: at,
        offConfirmed: confirmed,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'day_id': dayId,
    'pass': pass,
    'duty_on_at': dutyOnAt.toUtc().toIso8601String(),
    'auto_off_at': autoOffAt.toUtc().toIso8601String(),
    'off_at': offAt?.toUtc().toIso8601String(),
    'off_confirmed': offConfirmed,
  };
}
