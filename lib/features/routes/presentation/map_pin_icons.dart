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

  /// Live map: a round pin with the person's initials, white with a green
  /// ring (sending live).
  teamLive,

  /// Live map: amber pin with a halo (no update for over 5 minutes).
  teamStale,

  /// Live map: red pin with a halo (the latest point was fake GPS).
  teamFake,

  /// Live map: white pin with a blue ring (duty finished, last position).
  teamDone,
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
    PinStyle.stop ||
    PinStyle.visit ||
    PinStyle.end ||
    PinStyle.teamLive ||
    PinStyle.teamStale ||
    PinStyle.teamFake ||
    PinStyle.teamDone => const Offset(0.5, 1),
    _ => const Offset(0.5, 0.5),
  };

  static Future<BitmapDescriptor> icon(PinStyle style, {String label = ''}) =>
      _cache.putIfAbsent('${style.name}:$label', () => _draw(style, label));

  static Future<BitmapDescriptor> _draw(PinStyle style, String label) async {
    final Size size = switch (style) {
      PinStyle.stop || PinStyle.visit || PinStyle.end => const Size(32, 42),
      PinStyle.start => const Size(26, 26),
      PinStyle.person => const Size(44, 44),
      PinStyle.teamLive ||
      PinStyle.teamStale ||
      PinStyle.teamFake ||
      PinStyle.teamDone => const Size(64, 68),
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
      case PinStyle.teamLive:
        _personPin(canvas, ring: DsColors.successDot, label: label);
      case PinStyle.teamDone:
        _personPin(
          canvas,
          ring: const Color(0xFF0EA5E9),
          text: DsColors.primary,
          label: label,
        );
      case PinStyle.teamStale:
        _personPin(
          canvas,
          ring: DsColors.warningDot,
          label: label,
          alert: true,
        );
      case PinStyle.teamFake:
        _personPin(
          canvas,
          ring: DsColors.dangerText,
          label: label,
          alert: true,
        );
      case PinStyle.person:
        const Color color = DsColors.primary;
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

  /// A round pin with initials and a point at the bottom (live map). An
  /// [alert] pin is filled with the [ring] colour, has a white edge and a
  /// soft halo; the others are white with a coloured ring.
  static void _personPin(
    Canvas canvas, {
    required Color ring,
    required String label,
    Color? text,
    bool alert = false,
  }) {
    const Offset c = Offset(32, 30);
    const double r = 21;
    if (alert) {
      canvas.drawCircle(c, 30, Paint()..color = ring.withValues(alpha: 0.22));
    }
    final Path tip = Path()
      ..moveTo(c.dx - 9, c.dy + r - 4)
      ..lineTo(c.dx, c.dy + r + 15)
      ..lineTo(c.dx + 9, c.dy + r - 4)
      ..close();
    final Path body = Path()
      ..addOval(Rect.fromCircle(center: c, radius: r))
      ..addPath(tip, Offset.zero);
    canvas
      ..drawShadow(body, const Color(0x660F172A), 3, false)
      ..drawPath(tip, Paint()..color = ring)
      ..drawCircle(c, r, Paint()..color = alert ? DsColors.white : ring)
      ..drawCircle(c, r - 3, Paint()..color = alert ? ring : DsColors.white);
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: label,
        style: DsText.label.copyWith(
          color: alert ? DsColors.white : (text ?? DsColors.successText),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
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
