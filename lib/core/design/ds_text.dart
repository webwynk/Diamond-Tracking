import 'package:flutter/material.dart';

import 'ds_colors.dart';

/// The type scale of the new design: DM Sans only, 10 sizes plus the text
/// link, weights 500, 600 and 700 (design v2, section 02).
///
/// DM Sans is a variable font, so each style sets the weight twice:
/// fontWeight for Flutter's matching, fontVariations for the drawn weight.
abstract final class DsText {
  const DsText._();

  static const String family = 'DMSans';

  static const List<FontVariation> _w500 = <FontVariation>[
    FontVariation('wght', 500),
  ];
  static const List<FontVariation> _w600 = <FontVariation>[
    FontVariation('wght', 600),
  ];
  static const List<FontVariation> _w700 = <FontVariation>[
    FontVariation('wght', 700),
  ];

  /// 40 bold. The big figure on a hero card: "4h 12m".
  static const TextStyle number = TextStyle(
    fontFamily: family,
    fontSize: 40,
    height: 1.1,
    letterSpacing: -1.2,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    color: DsColors.ink,
  );

  /// 32 bold. Sign-in headings: "Good to see you."
  static const TextStyle display = TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 1.15,
    letterSpacing: -1.1,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    color: DsColors.ink,
  );

  /// 24 bold. Screen titles: "My requests".
  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 24,
    height: 1.2,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    color: DsColors.ink,
  );

  /// 20 bold. Values in tiles: "7:30 AM", "38 km".
  static const TextStyle value = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    color: DsColors.ink,
  );

  /// 17 bold. Section headings: "Visits today".
  static const TextStyle section = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    color: DsColors.ink,
  );

  /// 16 bold. Button labels.
  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
  );

  /// 15 medium. Body text and row titles.
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w500,
    fontVariations: _w500,
    color: DsColors.ink,
  );

  /// 14 bold, primary. Text links for small extras only.
  static const TextStyle link = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    color: DsColors.primary,
  );

  /// 13 semi-bold, Text 2. Field labels.
  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
    color: DsColors.text2,
  );

  /// 12 medium, Text 2. Captions and times: "8:12 AM · Barasat".
  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
    fontVariations: _w500,
    color: DsColors.text2,
  );

  /// 11 semi-bold, Text 2. Tile labels: "Distance".
  static const TextStyle micro = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
    color: DsColors.text2,
  );
}
