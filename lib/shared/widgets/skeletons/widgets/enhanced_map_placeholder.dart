import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// Section 5: Map Placeholder with CAD blueprint grid and architectural note.
///
/// RULE (Design System 7): Maps are strictly forbidden from using a shimmer skeleton.
/// Instead, they display this branded vector CAD placeholder to eliminate high GPU
/// redraw spikes under harsh sunlight.
class EnhancedMapPlaceholder extends StatelessWidget {
  const EnhancedMapPlaceholder({
    super.key,
    this.height = 180,
    this.showCalloutNote = true,
  });

  final double height;
  final bool showCalloutNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('skeleton-map-placeholder'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Map CAD Canvas Placeholder
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.primary100),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // CAD Blueprint Overlay Custom Painter
              Positioned.fill(
                child: CustomPaint(
                  painter: _CadBlueprintPainter(),
                ),
              ),

              // Centered Floating Status Widget
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // 48x48 Glassmorphic Circle
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xCCFFFFFF),
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Color(0x0F000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.location_on,
                        size: 32,
                        color: AppColors.neutral400,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'LOADING MAP…',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral400,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      fontSize: 11,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    'TRIANGULATING SATELLITE FIX',
                    style: AppTypography.overline.copyWith(
                      color: AppColors.primary600,
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Architectural Note Banner
        if (showCalloutNote) ...<Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x99E8F3F8),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.primary600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral600,
                        fontSize: 11,
                        height: 1.4,
                      ),
                      children: const <TextSpan>[
                        TextSpan(
                          text: 'NOTE: ',
                          style: TextStyle(
                            color: AppColors.neutral900,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextSpan(
                          text:
                              'A map never gets a shimmer skeleton — it displays this branded vector placeholder instead to prevent high GPU redraw spikes in harsh sunlight.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CadBlueprintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.primary100
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;

    const cellSize = 24.0;
    for (double x = 0; x <= size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Crosshairs
    final crosshairPaint = Paint()
      ..color = const Color(0x4D016893)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    _drawDashedLine(canvas, Offset(0, centerY), Offset(size.width, centerY), crosshairPaint);
    _drawDashedLine(canvas, Offset(centerX, 0), Offset(centerX, size.height), crosshairPaint);

    // Concentric Dashed Radar Ring
    final ringPaint = Paint()
      ..color = const Color(0x66016893)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const dashCount = 20;
    const radius = 48.0;
    for (var i = 0; i < dashCount; i++) {
      final angle = (i * 2 * math.pi) / dashCount;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
        angle,
        (2 * math.pi / dashCount) * 0.5,
        false,
        ringPaint,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final count = (math.sqrt(dx * dx + dy * dy) / (dashWidth + dashSpace)).floor();
    for (var i = 0; i < count; i++) {
      final start = Offset(
        p1.dx + (dx / count) * i,
        p1.dy + (dy / count) * i,
      );
      final end = Offset(
        p1.dx + (dx / count) * (i + 0.5),
        p1.dy + (dy / count) * (i + 0.5),
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
