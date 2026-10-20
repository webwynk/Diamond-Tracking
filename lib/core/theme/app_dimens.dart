import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Spacing, on a 4 dp base.
///
/// Source of truth: docs/03-DESIGN-SYSTEM.md section 4.
/// **Never write a literal spacing number anywhere else.**
abstract final class AppSpacing {
  const AppSpacing._();

  /// 4. Icon-to-text gap.
  static const double x1 = 4;

  /// 8. Inside a chip or dense row. Also the minimum gap between touch targets.
  static const double x2 = 8;

  /// 12. Between related elements.
  static const double x3 = 12;

  /// 16. **Default.** Screen side padding and card padding.
  static const double x4 = 16;

  /// 20. Card padding on a roomy layout.
  static const double x5 = 20;

  /// 24. Between sections.
  static const double x6 = 24;

  /// 32. Above a major section.
  static const double x8 = 32;

  /// 48. Top and bottom of a centred state.
  static const double x12 = 48;

  /// Horizontal screen padding. **Always 16. No horizontal page scroll, ever.**
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: x4);

  /// Default card padding.
  static const EdgeInsets card = EdgeInsets.all(x4);
}

/// Corner radii.
///
/// Source of truth: docs/03-DESIGN-SYSTEM.md section 4.
abstract final class AppRadius {
  const AppRadius._();

  /// 8. Chips, small buttons, badges.
  static const double sm = 8;

  /// 12. **Default.** Inputs, buttons, cards.
  static const double md = 12;

  /// 16. Large cards, sheets.
  static const double lg = 16;

  /// 24. Bottom sheets, modals.
  static const double xl = 24;

  /// 999. Avatars, pills, the duty toggle.
  static const double full = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));

  /// Top corners only, for a bottom sheet.
  static const BorderRadius xlTop = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// Fixed sizes with a rule attached.
abstract final class AppSizes {
  const AppSizes._();

  /// 48. **Minimum touch target. No exceptions, including icon buttons.**
  static const double minTouchTarget = 48;

  /// 48. Standard button and input height.
  static const double controlHeight = 48;

  /// 56. Height of every top app bar, below the status bar.
  static const double appBarHeight = 56;

  /// 72. Minimum list row height.
  static const double listRowMinHeight = 72;

  /// 24. Default icon.
  static const double icon = 24;

  /// 20. Dense icon.
  static const double iconDense = 20;
}

/// Elevation.
///
/// Keep it flat: prefer a [AppColors.border] border over a heavy shadow.
abstract final class AppElevation {
  const AppElevation._();

  /// Flat on the background, with a border. Not a shadow.
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Card. A very soft shadow.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// Sticky header, floating action button.
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(color: Color(0x140F172A), blurRadius: 8, offset: Offset(0, 2)),
  ];
}

/// Motion.
///
/// Respect the system "reduce motion" setting: fall back to a cross-fade.
abstract final class AppMotion {
  const AppMotion._();

  /// 1.5 s. Skeleton shimmer cycle.
  static const Duration shimmer = Duration(milliseconds: 1500);
}
