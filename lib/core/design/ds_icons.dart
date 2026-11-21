import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Every icon of the new design, by what it means (design v2, section 09:
/// 24 grid, stroke 2, round ends). Screens use these names, so an icon can
/// be swapped in one place.
abstract final class DsIcons {
  const DsIcons._();

  // Navigation
  static const IconData home = LucideIcons.house;
  static const IconData map = LucideIcons.map;
  static const IconData history = LucideIcons.calendar;
  static const IconData profile = LucideIcons.user;
  static const IconData back = LucideIcons.chevronLeft;
  static const IconData forward = LucideIcons.chevronRight;
  static const IconData arrow = LucideIcons.arrowRight;
  static const IconData close = LucideIcons.x;

  // Things
  static const IconData bell = LucideIcons.bell;
  static const IconData camera = LucideIcons.camera;
  static const IconData gallery = LucideIcons.image;
  static const IconData attach = LucideIcons.paperclip;
  static const IconData message = LucideIcons.messageSquareText;
  static const IconData pin = LucideIcons.mapPin;
  static const IconData lock = LucideIcons.lock;
  static const IconData clock = LucideIcons.clock;
  static const IconData phone = LucideIcons.phone;
  static const IconData search = LucideIcons.search;
  static const IconData requests = LucideIcons.inbox;

  // Actions and states
  static const IconData check = LucideIcons.check;
  static const IconData add = LucideIcons.plus;
  static const IconData show = LucideIcons.eye;
  static const IconData hide = LucideIcons.eyeOff;
  static const IconData retry = LucideIcons.refreshCw;
  static const IconData offline = LucideIcons.wifiOff;
  static const IconData warning = LucideIcons.triangleAlert;
  static const IconData error = LucideIcons.circleAlert;
  static const IconData info = LucideIcons.info;
  static const IconData empty = LucideIcons.inbox;

  // Duty
  static const IconData dutyOn = LucideIcons.play;
  static const IconData dutyOff = LucideIcons.square;
  static const IconData closed = LucideIcons.calendarX;
  static const IconData dayDone = LucideIcons.circleCheck;
  static const IconData waiting = LucideIcons.hourglass;
  static const IconData upload = LucideIcons.cloudUpload;
  static const IconData sickLeave = LucideIcons.heartPulse;
  static const IconData casualLeave = LucideIcons.palmtree;
  static const IconData attendance = LucideIcons.clipboardCheck;
  static const IconData battery = LucideIcons.batteryLow;
}
