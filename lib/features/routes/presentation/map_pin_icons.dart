import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_text.dart';

/// The look of a pin on the map (design v2, My map and Live map).
enum PinStyle {
  /// Green ring: where the duty started.
  start,

  /// Brand teardrop with a number: a stop.
  stop,

  /// Purple teardrop: a dealer visit.
  visit,

  /// Dark teardrop: where the duty ended.
  end,

  /// Blue dot with a halo: where the person is now.
  person,

  /// Amber dot with a halo: last seen more than 5 minutes ago.
  personStale,
}

/// Drawn pin images, made once per look and label, then reused.
///
/// Google's map takes markers as PNG pictures; these are painted in Flutter
/// so they match the app's design instead of Google's default balloons.
class MapPinIcons {
  MapPinIcons._();

  static final Map<String, Future<BitmapDescriptor>> _cache =
      <String, Future<BitmapDescriptor>>{};

  /// Pixels per logical point the pictures are drawn at: sharp on every
  /// phone, scaled down by the map.
  static const double _scale = 3;

  static const Color visitColor = Color(0xFF7C3AED);

  /// Where on the picture the map point is, as a fraction (0..1).
  static Offset anchorOf(PinStyle style) => switch (style) {
    PinStyle.stop || PinStyle.visit || PinStyle.end => const Offset(0.5, 1),
    _ => const Offset(0.5, 0.5),
  };

  static Future<BitmapDescriptor> icon(PinStyle style, {String label = ''}) =>
      _cache.putIfAbsent('${style.name}:$label', () => _draw(style, label));

  static Future<BitmapDescriptor> _draw(PinStyle style, String label) async {
    final Size size = switch (style) {
      PinStyle.stop || PinStyle.visit || PinStyle.end => const Size(32, 42),
      PinStyle.start => const Size(26, 26),
      PinStyle.person || PinStyle.personStale => const Size(44, 44),
    };
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)..scale(_scale);
    switch (style) {
      case PinStyle.start:
        final Offset c = size.center(Offset.zero);
        canvas
          ..drawCircle(c, 10, Paint()..color = DsColors.white)
          ..drawCircle(
            c,
            9,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..color = const Color(0xFF16A34A),
          );
      case PinStyle.stop:
        _teardrop(canvas, size, DsColors.primary);
        _label(canvas, size, label.isEmpty ? '•' : label);
      case PinStyle.visit:
        _teardrop(canvas, size, visitColor);
        _label(canvas, size, label.isEmpty ? '•' : label);
      case PinStyle.end:
        _teardrop(canvas, size, DsColors.ink);
        _label(canvas, size, '■');
      case PinStyle.person:
      case PinStyle.personStale:
        final Color color = style == PinStyle.person
            ? DsColors.primary
            : const Color(0xFFD97706);
        final Offset c = size.center(Offset.zero);
        canvas
          ..drawCircle(c, 21, Paint()..color = color.withValues(alpha: 0.14))
          ..drawCircle(c, 13, Paint()..color = color.withValues(alpha: 0.22))
          ..drawCircle(c, 9, Paint()..color = DsColors.white)
          ..drawCircle(c, 6.5, Paint()..color = color);
    }
    final ui.Image image = await recorder.endRecording().toImage(
      (size.width * _scale).ceil(),
      (size.height * _scale).ceil(),
    );
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    return BytesMapBitmap(
      png!.buffer.asUint8List(),
      width: size.width,
      height: size.height,
    );
  }

  /// A round-topped pin with a white edge, its point at the bottom middle.
  static void _teardrop(Canvas canvas, Size size, Color color) {
    final double w = size.width;
    final double h = size.height;
    final double r = w / 2 - 1.5;
    final Path pin = Path()
      ..moveTo(w / 2, h - 1)
      ..cubicTo(w / 2 - 4, h - 9, 1.5, h - 15, 1.5, r + 1.5)
      ..arcToPoint(Offset(w - 1.5, r + 1.5), radius: Radius.circular(r))
      ..cubicTo(w - 1.5, h - 15, w / 2 + 4, h - 9, w / 2, h - 1)
      ..close();
    canvas
      ..drawPath(pin, Paint()..color = color)
      ..drawPath(
        pin,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = DsColors.white,
      );
  }

  static void _label(Canvas canvas, Size size, String text) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: DsText.label.copyWith(
          color: DsColors.white,
          fontWeight: FontWeight.w700,
          fontSize: text.length > 2 ? 10 : 13,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double r = size.width / 2 - 1.5;
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, r + 1.5 - tp.height / 2),
    );
    tp.dispose();
  }
}
