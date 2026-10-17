import 'package:flutter/foundation.dart';

/// What happened, for the admin notification centre. The wire names are the
/// `type` values the database writes (`public.notifications.type`).
enum AdminNotificationType {
  dutyOn('duty_on'),
  dutyOff('duty_off'),
  dutyAutoEnded('duty_auto_ended'),
  mockGps('mock_gps'),
  batteryLow('battery_low'),
  noSignal('no_signal');

  const AdminNotificationType(this.wire);

  /// The value stored in the database.
  final String wire;

  /// A duty started or ended.
  bool get isDutyEvent =>
      this == dutyOn || this == dutyOff || this == dutyAutoEnded;

  /// Something that may need an admin to act (tracking broken, fake GPS,
  /// battery).
  bool get isAlert => this == mockGps || this == batteryLow || this == noSignal;

  /// Null for a type this app does not know (a newer server), so one unknown
  /// row never breaks the list.
  static AdminNotificationType? fromWire(Object? wire) {
    for (final type in values) {
      if (type.wire == wire) return type;
    }
    return null;
  }

  static const List<AdminNotificationType> dutyTypes = <AdminNotificationType>[
    dutyOn,
    dutyOff,
    dutyAutoEnded,
  ];

  static const List<AdminNotificationType> alertTypes = <AdminNotificationType>[
    mockGps,
    batteryLow,
    noSignal,
  ];
}

/// One notification, as the server holds it, plus whether THIS admin has read
/// it. Wording, icons and colours belong to the screen, not here.
@immutable
class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.type,
    required this.employeeId,
    required this.createdAt,
    this.sessionId,
    this.details = const <String, dynamic>{},
    this.isRead = false,
  });

  final int id;
  final AdminNotificationType type;
  final String employeeId;
  final String? sessionId;

  /// Extra facts for the wording: `battery_level`, `last_seen`, `never_sent`,
  /// `status`, `end_reason`.
  final Map<String, dynamic> details;

  /// When the server wrote it (UTC).
  final DateTime createdAt;
  final bool isRead;

  /// Reads one row of `list_notifications` or a Realtime insert (which has no
  /// `is_read`, and a brand-new notification is unread). Null when the row
  /// cannot be a notification or is of a type this app does not know.
  static AdminNotification? tryParse(Map<String, dynamic> json) {
    final id = json['id'];
    final type = AdminNotificationType.fromWire(json['type']);
    final employee = json['employee_id'];
    final created = json['created_at'];
    if (id is! num ||
        type == null ||
        employee is! String ||
        created is! String) {
      return null;
    }
    final at = DateTime.tryParse(created);
    if (at == null) return null;
    final session = json['session_id'];
    final details = json['details'];
    return AdminNotification(
      id: id.toInt(),
      type: type,
      employeeId: employee,
      sessionId: session is String ? session : null,
      details: details is Map
          ? Map<String, dynamic>.from(details)
          : const <String, dynamic>{},
      createdAt: at.toUtc(),
      isRead: json['is_read'] == true,
    );
  }

  AdminNotification copyWith({bool? isRead}) {
    return AdminNotification(
      id: id,
      type: type,
      employeeId: employeeId,
      sessionId: sessionId,
      details: details,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
