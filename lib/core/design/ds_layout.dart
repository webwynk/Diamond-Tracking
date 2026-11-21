import 'package:flutter/widgets.dart';

/// Spacing scale: 4, 8, 12, 16, 24, 32. Nothing in between.
abstract final class DsSpace {
  const DsSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Left and right margin of every screen.
  static const double gutter = 16;
}

/// The 4 corner styles of the whole app.
abstract final class DsRadius {
  const DsRadius._();

  /// Buttons, chips, the bottom bar.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  /// Cards, hero cards, bottom sheets.
  static const BorderRadius large = BorderRadius.all(Radius.circular(24));

  /// Fields, tiles, date blocks.
  static const BorderRadius medium = BorderRadius.all(Radius.circular(16));

  /// The top of a bottom sheet.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(24),
  );
}

/// Shadows of the new design.
abstract final class DsShadow {
  const DsShadow._();

  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x140F172A), offset: Offset(0, 10), blurRadius: 26),
  ];

  static const List<BoxShadow> button = <BoxShadow>[
    BoxShadow(color: Color(0x40016893), offset: Offset(0, 10), blurRadius: 24),
  ];

  static const List<BoxShadow> navBar = <BoxShadow>[
    BoxShadow(color: Color(0x4D0F172A), offset: Offset(0, 12), blurRadius: 30),
  ];
}

/// Sizes that must stay the same everywhere.
abstract final class DsSize {
  const DsSize._();

  /// Main buttons and fields.
  static const double control = 56;

  /// Smallest tap area (Android's minimum).
  static const double tap = 48;

  /// Small buttons inside rows look this tall; their tap area is [tap].
  static const double smallButton = 38;

  /// The floating bottom bar.
  static const double navBar = 64;

  /// Space a screen keeps below its content for the floating bottom bar,
  /// on top of the phone's own bottom inset.
  static const double navBarClearance = navBar + 16 + 16;
}
