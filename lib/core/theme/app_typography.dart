import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The type scale.
///
/// Source of truth: docs/03-DESIGN-SYSTEM.md section 3.
///
/// **Never write a literal font size anywhere else.**
///
/// DM Sans is bundled as a **variable** font, so weight is selected with
/// [FontVariation] on the `wght` axis rather than relying on [FontWeight]
/// alone. `fontWeight` snaps to the nearest axis instance and is imprecise for
/// the 500 and 600 steps this scale uses, so both are set: `fontWeight` for
/// Flutter's own fallback and matching logic, `fontVariations` for the actual
/// rendered weight.
abstract final class AppTypography {
  const AppTypography._();

  /// The bundled family name, as declared in pubspec.yaml.
  static const String fontFamily = 'DMSans';

  // Only these four weights are used. Do not add others.
  static const List<FontVariation> _w400 = <FontVariation>[
    FontVariation('wght', 400),
  ];
  static const List<FontVariation> _w500 = <FontVariation>[
    FontVariation('wght', 500),
  ];
  static const List<FontVariation> _w600 = <FontVariation>[
    FontVariation('wght', 600),
  ];
  static const List<FontVariation> _w700 = <FontVariation>[
    FontVariation('wght', 700),
  ];

  /// 32/40 Bold. The km and hours figures on the duty screen.
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    color: AppColors.textPrimary,
  );

  /// 28/36 Bold. Screen title on a large header.
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    color: AppColors.textPrimary,
  );

  /// 24/32 SemiBold. Section heading.
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
    color: AppColors.textPrimary,
  );

  /// 20/28 SemiBold. Card title, app bar title.
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
    color: AppColors.textPrimary,
  );

  /// 18/26 SemiBold. List item title, dialog title.
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
    color: AppColors.textPrimary,
  );

  /// 16/24 Regular. Primary reading text, input text.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    fontVariations: _w400,
    color: AppColors.textPrimary,
  );

  /// 14/20 Regular. Default body, list subtitle.
  ///
  /// This is the **minimum body size**. Nothing smaller carries text the user
  /// must read in order to act.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    fontVariations: _w400,
    color: AppColors.textPrimary,
  );

  /// 13/18 Medium. Button text, chip text, field label.
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    fontVariations: _w500,
    color: AppColors.textPrimary,
  );

  /// 12/16 Regular. Timestamps, helper text.
  ///
  /// Never used for anything the user must read in order to act.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    fontVariations: _w400,
    color: AppColors.textSecondary,
  );

  /// 11/16 SemiBold, +0.5 letter spacing. Section micro-headings, uppercase.
  ///
  /// Write the text in uppercase at the call site; this style does not
  /// transform it.
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
  );
}

/// Helpers for applying the typography rules.
extension AppTextStyleX on TextStyle {
  /// Tabular (fixed-width) figures.
  ///
  /// **Required for any number in a stat card, table or list column**, so
  /// columns do not jitter as live values change. A duty timer counting up with
  /// proportional figures visibly shifts every second.
  TextStyle get tabular =>
      copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]);

  /// Recolour without restating the rest of the style.
  TextStyle withColor(Color color) => copyWith(color: color);
}
