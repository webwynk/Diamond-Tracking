import 'package:flutter/material.dart';

/// Every colour in the app.
///
/// Source of truth: docs/03-DESIGN-SYSTEM.md section 2.
///
/// **Never write a literal hex anywhere else.** If a colour you need is not
/// here, add it to the design system document first and get approval.
///
/// This app is **light mode only**. No colour here is intended for a dark
/// surface, with the single documented exception of [snackbarSurface].
abstract final class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------------------
  // Brand ramp. #016893 is the brand and sits at primary600.
  // ---------------------------------------------------------------------------

  /// Page tint, selected-row background.
  static const Color primary50 = Color(0xFFE8F3F8);

  /// Chip background, subtle fill.
  static const Color primary100 = Color(0xFFC5E1EC);

  /// Borders on tinted surfaces.
  static const Color primary200 = Color(0xFF9ECDDF);

  /// Disabled brand elements.
  static const Color primary300 = Color(0xFF76B9D2);

  /// Illustrations, map chrome, decorative accents.
  ///
  /// **Too light for text on white.** See [primary600] for the text rule.
  static const Color primary400 = Color(0xFF4AA5C6);

  /// Hover and pressed on light.
  static const Color primary500 = Color(0xFF0E86B4);

  /// **THE BRAND COLOUR.** Buttons, app bar, active states, links.
  ///
  /// Verified contrast: 6.17:1 against white, both as text on white and as
  /// white text on it. Passes WCAG AA for normal text; does not reach AAA.
  ///
  /// **Only this shade and darker may be used for text or icons.** [primary500]
  /// and lighter do not reach 4.5:1 on white and are for fills and decoration.
  static const Color primary600 = Color(0xFF016893);

  /// Pressed state on light.
  static const Color primary700 = Color(0xFF015676);

  /// Headings on tinted surfaces.
  static const Color primary800 = Color(0xFF01425A);

  /// Deepest brand shade.
  static const Color primary900 = Color(0xFF002938);

  // ---------------------------------------------------------------------------
  // Neutrals
  // ---------------------------------------------------------------------------

  /// Cards and sheets.
  static const Color neutral0 = Color(0xFFFFFFFF);

  /// Page background.
  static const Color neutral50 = Color(0xFFF8FAFC);

  /// Subtle fill, skeleton base.
  static const Color neutral100 = Color(0xFFF1F5F9);

  /// Dividers, borders.
  static const Color neutral200 = Color(0xFFE2E8F0);

  /// Input borders, skeleton shimmer.
  static const Color neutral300 = Color(0xFFCBD5E1);

  /// Placeholder text, disabled text, off-duty status.
  static const Color neutral400 = Color(0xFF94A3B8);

  /// Secondary text.
  static const Color neutral500 = Color(0xFF64748B);

  /// Body text.
  static const Color neutral600 = Color(0xFF475569);

  /// Strong body text, icon on a light fill.
  static const Color neutral700 = Color(0xFF334155);

  /// Blocked status.
  static const Color neutral800 = Color(0xFF1E293B);

  /// Primary text, headings.
  static const Color neutral900 = Color(0xFF0F172A);

  // ---------------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------------

  /// On duty, uploaded, saved.
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);

  /// Stale location, queued offline, low battery.
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFEF3C7);

  /// Fake-GPS flag, GPS off, failure.
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEE2E2);

  /// Neutral information. Offline is info, not error.
  static const Color info = Color(0xFF0284C7);
  static const Color infoBg = Color(0xFFE0F2FE);

  // ---------------------------------------------------------------------------
  // Duty status
  //
  // Must match the PRD status table exactly. Used by map, lists and reports.
  //
  // RULE: always render the label alongside the colour. Never colour alone.
  // Use AppStatusColors.labelFor to get the matching text.
  // ---------------------------------------------------------------------------

  /// On duty, position fresh.
  static const Color statusActive = success;

  /// On duty but no update for over 5 minutes.
  static const Color statusStale = warning;

  /// Mock location flagged, or location services off.
  static const Color statusSuspect = error;

  /// No open duty session.
  static const Color statusOff = neutral400;

  /// Account blocked.
  static const Color statusBlocked = neutral800;

  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  /// Page background.
  static const Color background = neutral50;

  /// Card and sheet surface.
  static const Color surface = neutral0;

  /// Divider and default border.
  static const Color border = neutral200;

  /// Primary text.
  static const Color textPrimary = neutral900;

  /// Secondary text.
  static const Color textSecondary = neutral500;

  /// Placeholder and disabled text.
  static const Color textDisabled = neutral400;

  /// Snackbar background.
  ///
  /// **The one deliberately dark surface in a light-only app.** A snackbar is a
  /// transient overlay, not a theme. Its action colour is [primary400], which
  /// gives 5.22:1 against this background and passes WCAG AA. Do not use
  /// [primary600] here: it is far too dark to read on this surface.
  static const Color snackbarSurface = neutral800;

  /// Action text on [snackbarSurface].
  static const Color snackbarAction = primary400;
}

/// Pairs a duty status colour with the text that must always accompany it.
///
/// Exists so the design system rule "status is colour **plus** a text label,
/// never colour alone" is awkward to break. Reach for this rather than using a
/// `status*` colour directly.
///
/// The real `DutyStatus` enum arrives with the schema in Phase 2; until then
/// these string keys mirror the PRD status table.
abstract final class AppStatusColors {
  const AppStatusColors._();

  /// Status key to colour.
  static const Map<String, Color> colours = <String, Color>{
    'active': AppColors.statusActive,
    'stale': AppColors.statusStale,
    'suspect': AppColors.statusSuspect,
    'off': AppColors.statusOff,
    'blocked': AppColors.statusBlocked,
  };

  /// Status key to the label shown to the user. Required, never optional.
  static const Map<String, String> labels = <String, String>{
    'active': 'On duty',
    'stale': 'No update 5 min',
    'suspect': 'Check needed',
    'off': 'Off duty',
    'blocked': 'Blocked',
  };

  /// Background tint for a status pill.
  static const Map<String, Color> backgrounds = <String, Color>{
    'active': AppColors.successBg,
    'stale': AppColors.warningBg,
    'suspect': AppColors.errorBg,
    'off': AppColors.neutral100,
    'blocked': AppColors.neutral200,
  };
}
