import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_live_map_state.dart';

/// Upper focused map canvas for Screen 16 (Live Map Employee Detail Sheet).
///
/// Features:
/// - Stylized agricultural topography (canals, parcels, village road network)
/// - Officer trailing live route path with breadcrumb telemetry dots
/// - Subdued background peer field officers
/// - Highlighted 40dp circular officer marker with spatial beacon tag
/// - Top floating controls: Back button, Sector pill, and Recenter GPS button
/// - Bottom geofence status badge
class LiveMapFocusedCanvas extends StatefulWidget {
  const LiveMapFocusedCanvas({
    super.key,
    required this.officer,
    this.onBack,
    this.onRecenter,
  });

  final MapOfficerItem officer;
  final VoidCallback? onBack;
  final VoidCallback? onRecenter;

  @override
  State<LiveMapFocusedCanvas> createState() => _LiveMapFocusedCanvasState();
}

class _LiveMapFocusedCanvasState extends State<LiveMapFocusedCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    // Gentle pulse animation around the selected officer
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _resolveMarkerColor() {
    switch (widget.officer.status) {
      case AdminOfficerStatus.onDuty:
        return AppColors.success;
      case AdminOfficerStatus.stale:
        return AppColors.warning;
      case AdminOfficerStatus.needsCheck:
        return AppColors.error;
      case AdminOfficerStatus.offDuty:
        return AppColors.neutral400;
      case AdminOfficerStatus.blocked:
        return const Color(0xFF1E293B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final markerColor = _resolveMarkerColor();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final centerX = w * 0.5;
        final centerY = h * 0.52;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Regional Vector Topography Painter with Trails & Breadcrumbs
            Positioned.fill(
              child: CustomPaint(
                painter: _FocusedTopographyPainter(
                  markerColor: markerColor,
                  centerX: centerX,
                  centerY: centerY,
                ),
              ),
            ),

            // 2. Animated Pulse Rings behind the Officer Marker
            Positioned(
              left: centerX - 32,
              top: centerY - 32,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final radius = 24.0 + (_pulseAnimation.value * 8.0);
                  return Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    child: Container(
                      width: radius * 2,
                      height: radius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: markerColor.withValues(
                          alpha: 0.16 + (0.08 * (1 - _pulseAnimation.value)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 3. Highlighted Primary Officer Marker (40dp) with Beacon Tag
            Positioned(
              left: centerX - 20,
              top: centerY - 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: Key('focused-marker-${widget.officer.id}'),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: markerColor.withValues(alpha: 0.38),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Spatial Beacon Callout Tag
                  Container(
                    key: const Key('badge-focused-officer-tag'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x20000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.officer.calloutTag,
                      style: const TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Floating Top Context Bar (Back, Sector Pill, Recenter GPS)
            Positioned(
              top: AppSpacing.x3,
              left: AppSpacing.x4,
              right: AppSpacing.x4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Action Button
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    elevation: 1,
                    child: InkWell(
                      key: const Key('btn-focused-map-back'),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: widget.onBack ?? () => Navigator.of(context).pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),

                  // Right Controls: Sector Pill + Recenter
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sector Pill
                      Container(
                        key: const Key('badge-focused-map-sector'),
                        height: 44,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.officer.sectorText,
                              style: AppTypography.overline.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: AppSpacing.x2),

                      // Recenter GPS Button
                      Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        elevation: 1,
                        child: InkWell(
                          key: const Key('btn-focused-map-recenter'),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: widget.onRecenter ??
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Map centered on ${widget.officer.name}.',
                                    ),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1.0,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.my_location_rounded,
                              size: 20,
                              color: AppColors.primary600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 5. Floating Bottom-Left Geofence Attribution Badge
            Positioned(
              left: AppSpacing.x4,
              bottom: AppSpacing.x6,
              child: Container(
                key: const Key('badge-focused-map-geofence'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border, width: 1.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.crop_free_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.officer.geofenceText,
                      style: AppTypography.overline.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Custom painter rendering stylized regional topography, routes, breadcrumbs, and peer markers.
class _FocusedTopographyPainter extends CustomPainter {
  const _FocusedTopographyPainter({
    required this.markerColor,
    required this.centerX,
    required this.centerY,
  });

  final Color markerColor;
  final double centerX;
  final double centerY;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Base Land Background
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 2. Faint Grid Lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.5;
    const step = 32.0;
    for (double x = 0; x < w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y < h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // 3. Faint Canal / Water Contour
    final canalPaint = Paint()
      ..color = const Color(0xFFC5E1EC).withValues(alpha: 0.75)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final canalPath = Path()
      ..moveTo(-20, h * 0.3)
      ..quadraticBezierTo(w * 0.25, h * 0.38, w * 0.45, h * 0.3)
      ..quadraticBezierTo(w * 0.7, h * 0.22, w + 20, h * 0.34);
    canvas.drawPath(canalPath, canalPaint);

    // Branching Canal
    final branchPaint = Paint()
      ..color = const Color(0xFFC5E1EC).withValues(alpha: 0.5)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final branchPath = Path()
      ..moveTo(w * 0.45, h * 0.3)
      ..quadraticBezierTo(w * 0.6, h * 0.6, w * 0.82, h * 0.85);
    canvas.drawPath(branchPath, branchPaint);

    // 4. Agricultural Field Parcels (Subtle polygons)
    final parcelPaint = Paint()
      ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;
    final p1 = Path()
      ..moveTo(w * 0.05, h * 0.12)
      ..lineTo(w * 0.3, h * 0.08)
      ..lineTo(w * 0.35, h * 0.25)
      ..lineTo(w * 0.08, h * 0.26)
      ..close();
    canvas.drawPath(p1, parcelPaint);

    final p2 = Path()
      ..moveTo(w * 0.62, h * 0.09)
      ..lineTo(w * 0.94, h * 0.06)
      ..lineTo(w * 0.96, h * 0.24)
      ..lineTo(w * 0.64, h * 0.22)
      ..close();
    canvas.drawPath(p2, parcelPaint);

    final p3 = Path()
      ..moveTo(w * 0.1, h * 0.6)
      ..lineTo(w * 0.34, h * 0.54)
      ..lineTo(w * 0.39, h * 0.8)
      ..lineTo(w * 0.13, h * 0.85)
      ..close();
    canvas.drawPath(p3, parcelPaint);

    // 5. White Road Network
    final mainRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final road1 = Path()
      ..moveTo(-10, h * 0.5)
      ..lineTo(w * 0.36, h * 0.46)
      ..lineTo(centerX, centerY)
      ..lineTo(w * 0.72, h * 0.39)
      ..lineTo(w + 10, h * 0.42);
    canvas.drawPath(road1, mainRoadPaint);

    final secondaryRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final road2 = Path()
      ..moveTo(centerX, centerY)
      ..lineTo(w * 0.54, h * 0.76)
      ..lineTo(w * 0.68, h * 0.92);
    canvas.drawPath(road2, secondaryRoadPaint);

    // 6. Taluka & Village Typography Labels
    _drawLabel(canvas, 'KOTDA TALUKA', Offset(w * 0.08, h * 0.2), true);
    _drawLabel(canvas, 'VADOD SECTOR-4', Offset(w * 0.68, h * 0.16), true);
    _drawLabel(canvas, 'Shivpuri North', Offset(w * 0.12, h * 0.7), false);
    _drawLabel(canvas, 'Plot 12-B Canal', Offset(w * 0.68, h * 0.74), false);

    // 7. Subdued Background Peer Field Officers
    _drawPeerMarker(canvas, Offset(w * 0.21, h * 0.39), AppColors.success, 6.0);
    _drawPeerMarker(canvas, Offset(w * 0.82, h * 0.27), AppColors.success, 5.0);
    _drawPeerMarker(
        canvas, Offset(w * 0.73, h * 0.68), AppColors.neutral400, 6.0);

    // 8. Trailing Live Route Path for Focused Officer
    final trailPaint = Paint()
      ..color = markerColor.withValues(alpha: 0.9)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final trailPath = Path()
      ..moveTo(w * 0.32, h * 0.46)
      ..quadraticBezierTo(w * 0.41, h * 0.48, centerX, centerY);
    canvas.drawPath(trailPath, trailPaint);

    // 9. Breadcrumb Historical Telemetry Pings
    final b1 = Paint()..color = markerColor.withValues(alpha: 0.6);
    canvas.drawCircle(Offset(w * 0.34, h * 0.465), 2.0, b1);

    final b2 = Paint()..color = markerColor.withValues(alpha: 0.75);
    canvas.drawCircle(Offset(w * 0.39, h * 0.475), 2.5, b2);

    final b3 = Paint()..color = markerColor.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(w * 0.445, h * 0.495), 3.0, b3);
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, bool isUpper) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 10,
          fontWeight: isUpper ? FontWeight.w600 : FontWeight.w500,
          letterSpacing: isUpper ? 0.8 : 0.0,
          color: const Color(0xFF94A3B8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }

  void _drawPeerMarker(
      Canvas canvas, Offset offset, Color color, double radius) {
    final outerPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offset, radius, outerPaint);

    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offset, radius * 0.5, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _FocusedTopographyPainter oldDelegate) {
    return oldDelegate.markerColor != markerColor ||
        oldDelegate.centerX != centerX ||
        oldDelegate.centerY != centerY;
  }
}
