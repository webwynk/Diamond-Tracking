import 'package:flutter/material.dart';

import 'ds_colors.dart';

/// The one status colour set used on every screen (decided 2026-11-21).
///
/// Each status has a soft background (tint), a text colour and a dot.
enum DsStatus {
  present(
    tint: DsColors.successTint,
    text: DsColors.successText,
    dot: DsColors.successDot,
  ),
  halfDay(
    tint: Color(0xFFE0F2FE),
    text: Color(0xFF075985),
    dot: Color(0xFF0EA5E9),
  ),
  leave(
    tint: Color(0xFFF1EDFE),
    text: Color(0xFF6D28D9),
    dot: Color(0xFF8B5CF6),
  ),
  sick(
    tint: Color(0xFFFFE4E6),
    text: Color(0xFFBE123C),
    dot: Color(0xFFE11D48),
  ),
  absent(
    tint: DsColors.dangerTint,
    text: DsColors.dangerText,
    dot: DsColors.dangerDot,
  ),
  waiting(
    tint: DsColors.warningTint,
    text: DsColors.warningText,
    dot: DsColors.warningDot,
  ),
  onDuty(
    tint: DsColors.primaryTint,
    text: DsColors.primary,
    dot: DsColors.primary,
  ),
  off(tint: DsColors.disabled, text: DsColors.text2, dot: DsColors.text3);

  const DsStatus({required this.tint, required this.text, required this.dot});

  /// Soft background for pills, tiles and rows.
  final Color tint;

  /// Text and icons on [tint]. At least 4.5:1.
  final Color text;

  /// Dots, bars and map pins.
  final Color dot;
}
