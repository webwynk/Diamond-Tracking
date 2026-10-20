import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../core/utils/duty_time_helper.dart';
import '../../../../domain/entities/admin_notification.dart';

/// One notification worded for its row: who, what, when, and how it looks.
@immutable
class AdminNotificationRow {
  const AdminNotificationRow({
    required this.notification,
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.icon,
    required this.iconColor,
    required this.badgeColor,
  });

  final AdminNotification notification;

  /// "Asha Patil (DA-101)".
  final String title;

  /// "Started duty", "Battery low (14%)", ...
  final String subtitle;

  /// "2:35 PM", in IST.
  final String timeText;
  final IconData icon;
  final Color iconColor;
  final Color badgeColor;

  String get id => '${notification.id}';
  bool get isUnread => !notification.isRead;
}

/// Turns a notification into words, an icon and an IST time. Display only; the
/// server decides what a notification is (docs/05, Rule 3).
abstract final class AdminNotificationPresenter {
  const AdminNotificationPresenter._();

  static AdminNotificationRow row(
    AdminNotification notification, {
    required Map<String, ({String name, String? code})> names,
  }) {
    final person = names[notification.employeeId];
    final name = person?.name ?? 'An employee';
    final code = person?.code;
    final style = _style(notification.type);
    return AdminNotificationRow(
      notification: notification,
      title: code == null || code.isEmpty ? name : '$name ($code)',
      subtitle: subtitle(notification),
      timeText: DutyTimeHelper.formatTime(notification.createdAt),
      icon: style.icon,
      iconColor: style.color,
      badgeColor: style.background,
    );
  }

  static String subtitle(AdminNotification n) {
    switch (n.type) {
      case AdminNotificationType.dutyOn:
        return 'Started duty';
      case AdminNotificationType.dutyOff:
        return n.details['status'] == 'blocked'
            ? 'Ended duty (employee was blocked)'
            : 'Ended duty';
      case AdminNotificationType.dutyAutoEnded:
        return 'Duty ended automatically at 23:00';
      case AdminNotificationType.mockGps:
        return 'Fake GPS detected';
      case AdminNotificationType.batteryLow:
        final level = n.details['battery_level'];
        return level is num ? 'Battery low (${level.toInt()}%)' : 'Battery low';
      case AdminNotificationType.noSignal:
        if (n.details['never_sent'] == true) {
          return 'No location received since duty started';
        }
        final lastSeen = n.details['last_seen'];
        final at = lastSeen is String ? DateTime.tryParse(lastSeen) : null;
        return at == null
            ? 'No location received for 10+ minutes'
            : 'No location received since ${DutyTimeHelper.formatTime(at)}';
      case AdminNotificationType.accountLocked:
        final minutes = n.details['locked_minutes'];
        return minutes is num
            ? 'Locked for ${minutes.toInt()} minutes after 5 wrong PIN tries'
            : 'Locked after 5 wrong PIN tries';
      case AdminNotificationType.newDeviceLogin:
        return 'Login attempt from an unregistered phone';
      case AdminNotificationType.failedLogin:
        final attempts = n.details['attempts'];
        return attempts is num
            ? '$attempts failed PIN attempts'
            : 'Multiple failed PIN attempts';
      case AdminNotificationType.gpsDisabled:
        return 'Location service turned off while on duty';
    }
  }

  /// The IST day of a notification, as `yyyy-MM-dd` (what the route view opens
  /// on).
  static String istDayId(DateTime utc) {
    final ist = DutyTimeHelper.toIst(utc);
    return '${ist.year.toString().padLeft(4, '0')}-'
        '${ist.month.toString().padLeft(2, '0')}-'
        '${ist.day.toString().padLeft(2, '0')}';
  }

  /// "Today", "Yesterday" or "Sat, 11 Oct": the heading of the IST day a
  /// notification belongs to. [now] only decides which day is today; it is a
  /// heading, not a rule.
  static String dayHeading(DateTime createdAt, DateTime now) {
    final day = _istDate(createdAt);
    final today = _istDate(now);
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return DateLabels.shortDate(day);
  }

  static DateTime _istDate(DateTime instant) {
    final ist = DutyTimeHelper.toIst(instant);
    return DateTime(ist.year, ist.month, ist.day);
  }

  static ({IconData icon, Color color, Color background}) _style(
    AdminNotificationType type,
  ) {
    switch (type) {
      case AdminNotificationType.dutyOn:
        return (
          icon: Icons.login_rounded,
          color: AppColors.success,
          background: AppColors.successBg,
        );
      case AdminNotificationType.dutyOff:
        return (
          icon: Icons.logout_rounded,
          color: AppColors.neutral600,
          background: AppColors.neutral100,
        );
      case AdminNotificationType.dutyAutoEnded:
        return (
          icon: Icons.schedule_rounded,
          color: AppColors.warning,
          background: AppColors.warningBg,
        );
      case AdminNotificationType.mockGps:
        return (
          icon: Icons.gpp_maybe_rounded,
          color: AppColors.error,
          background: AppColors.errorBg,
        );
      case AdminNotificationType.batteryLow:
        return (
          icon: Icons.battery_alert_rounded,
          color: AppColors.warning,
          background: AppColors.warningBg,
        );
      case AdminNotificationType.noSignal:
        return (
          icon: Icons.signal_cellular_connected_no_internet_4_bar_rounded,
          color: AppColors.error,
          background: AppColors.errorBg,
        );
      case AdminNotificationType.accountLocked:
        return (
          icon: Icons.lock_clock_rounded,
          color: AppColors.error,
          background: AppColors.errorBg,
        );
      case AdminNotificationType.newDeviceLogin:
        return (
          icon: Icons.phonelink_erase_rounded,
          color: AppColors.error,
          background: AppColors.errorBg,
        );
      case AdminNotificationType.failedLogin:
        return (
          icon: Icons.password_rounded,
          color: AppColors.warning,
          background: AppColors.warningBg,
        );
      case AdminNotificationType.gpsDisabled:
        return (
          icon: Icons.location_off_rounded,
          color: AppColors.error,
          background: AppColors.errorBg,
        );
    }
  }
}
