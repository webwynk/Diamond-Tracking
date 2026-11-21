import 'package:flutter/material.dart';

/// Every colour of the new design (design v2, "Design system" page,
/// section 01). Same values on the admin and employee side.
///
/// Light mode only. Use these names, never a hex value in a screen.
abstract final class DsColors {
  const DsColors._();

  // Brand

  /// Buttons, links, active items. 6.2:1 on white.
  static const Color primary = Color(0xFF016893);

  /// Hero cards and headers.
  static const Color deep = Color(0xFF01425A);

  /// Tiles on a deep card.
  static const Color deepRaised = Color(0xFF0C5C7B);

  /// Soft buttons, icon tiles, info status.
  static const Color primaryTint = Color(0xFFE6F2F7);

  /// Accents on deep surfaces only.
  static const Color sky = Color(0xFF7DD3FC);

  /// Secondary text on deep surfaces.
  static const Color skyText = Color(0xFFA9CCDA);

  /// Text, the bottom bar, a selected chip.
  static const Color ink = Color(0xFF0F172A);

  // Neutrals

  /// Labels, secondary text and times. 6.2:1 on white.
  static const Color text2 = Color(0xFF536276);

  /// Hints, placeholders and arrows only. Too faint for text people must
  /// read (2.6:1), so never for times or values (decided 2026-11-21).
  static const Color text3 = Color(0xFF94A3B8);

  /// Borders and dividers.
  static const Color line = Color(0xFFE2E8F0);

  /// Disabled fill, empty bar.
  static const Color disabled = Color(0xFFEEF2F6);

  /// Page and field background.
  static const Color surface = Color(0xFFF2F5F8);

  /// Cards and sheets.
  static const Color white = Color(0xFFFFFFFF);

  /// The offline banner.
  static const Color slate = Color(0xFF1E293B);

  /// Behind a bottom sheet.
  static const Color scrim = Color(0x730F172A);

  // Feedback (tint, text, dot)

  static const Color successTint = Color(0xFFE8F6EC);
  static const Color successText = Color(0xFF15803D);
  static const Color successDot = Color(0xFF16A34A);

  static const Color warningTint = Color(0xFFFFF4DB);
  static const Color warningText = Color(0xFFB45309);
  static const Color warningDot = Color(0xFFF59E0B);

  static const Color dangerTint = Color(0xFFFEE2E2);
  static const Color dangerText = Color(0xFFB91C1C);
  static const Color dangerDot = Color(0xFFDC2626);

  /// Count badge for unread items.
  static const Color unreadBadge = Color(0xFFE11D48);

  /// Live dot on deep surfaces.
  static const Color liveOnDeep = Color(0xFF4ADE80);
}
