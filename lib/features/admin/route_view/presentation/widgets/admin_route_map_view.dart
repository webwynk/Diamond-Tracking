import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_route_view_state.dart';

/// Upper 62% cartographic route map view for Screen 23 Route View (Admin).
class AdminRouteMapView extends StatelessWidget {
  const AdminRouteMapView({
    super.key,
    required this.waypoints,
    required this.onWaypointTapped,
    required this.onFitRoute,
    required this.onToggleLayers,
    this.selectedWaypointId,
    this.isSatellite = false,
    this.showFlagExcludedRoute = true,
  });

  final List<AdminRouteWaypoint> waypoints;
  final ValueChanged<AdminRouteWaypoint> onWaypointTapped;
  final VoidCallback onFitRoute;
  final VoidCallback onToggleLayers;
  final String? selectedWaypointId;
  final bool isSatellite;
  final bool showFlagExcludedRoute;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          children: <Widget>[
            // 1. Regional Basemap & Route Trajectory Vector Canvas
            Positioned.fill(
              child: CustomPaint(
                painter: _RouteCartographyPainter(
                  isSatellite: isSatellite,
                  showFlagExcludedRoute: showFlagExcludedRoute,
                ),
              ),
            ),

            // 2. Geofence Overlay around Visit 3
            ...waypoints.where((w) => w.hasGeofence).map((w) {
              final x = w.relativeX * width;
              final y = w.relativeY * height;
              return Positioned(
                left: x - 45,
                top: y - 45,
                child: IgnorePointer(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary50.withValues(alpha: 0.65),
                      border: Border.all(
                        color: AppColors.primary600,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                  ),
                ),
              );
            }),

            // 3. Interactive Route Waypoint Markers
            ...waypoints.map((waypoint) {
              final x = waypoint.relativeX * width;
              final y = waypoint.relativeY * height;

              return Positioned(
                left: x - 18,
                top: y - 18,
                child: _buildWaypointMarker(waypoint),
              );
            }),

            // 4. OpenStreetMap Attribution (Bottom-Left)
            Positioned(
              left: AppSpacing.x4,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.neutral200.withValues(alpha: 0.8),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: AppTypography.overline.copyWith(
                    color: AppColors.neutral500,
                    fontSize: 10,
                  ),
                ),
              ),
            ),

            // 5. Floating Map Controls (Bottom-Right Vertical Stack)
            Positioned(
              right: AppSpacing.x4,
              bottom: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Fit to Route Button
                  _buildMapControlButton(
                    key: const Key('btn-map-fit-route'),
                    icon: Icons.crop_free_rounded,
                    iconColor: AppColors.primary600,
                    tooltip: 'Fit route to view',
                    onTap: onFitRoute,
                  ),
                  const SizedBox(height: AppSpacing.x2),

                  // Toggle Map Layers Button
                  _buildMapControlButton(
                    key: const Key('btn-map-layers'),
                    icon: Icons.layers_outlined,
                    iconColor: isSatellite
                        ? AppColors.primary600
                        : AppColors.neutral600,
                    tooltip: 'Toggle map layers',
                    onTap: onToggleLayers,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapControlButton({
    required Key key,
    required IconData icon,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral200, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Icon(
            icon,
            color: iconColor,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildWaypointMarker(AdminRouteWaypoint waypoint) {
    switch (waypoint.type) {
      case AdminWaypointType.start:
        return GestureDetector(
          key: Key('marker-${waypoint.id}'),
          onTap: () => onWaypointTapped(waypoint),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.neutral0, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: AppColors.neutral0,
              size: 16,
            ),
          ),
        );

      case AdminWaypointType.end:
        return GestureDetector(
          key: Key('marker-${waypoint.id}'),
          onTap: () => onWaypointTapped(waypoint),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.neutral800,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.neutral0, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.neutral0,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );

      case AdminWaypointType.visit:
        return GestureDetector(
          key: Key('marker-${waypoint.id}'),
          onTap: () => onWaypointTapped(waypoint),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary600,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.neutral0, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '${waypoint.visitNumber ?? 1}',
              style: AppTypography.caption.copyWith(
                color: AppColors.neutral0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );

      case AdminWaypointType.longStop:
        return GestureDetector(
          key: Key('marker-${waypoint.id}'),
          onTap: () => onWaypointTapped(waypoint),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.warning,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );

      case AdminWaypointType.flaggedAnomaly:
        return GestureDetector(
          key: Key('marker-${waypoint.id}'),
          onTap: () => onWaypointTapped(waypoint),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.neutral0, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x25DC2626),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.priority_high_rounded,
              color: AppColors.neutral0,
              size: 16,
            ),
          ),
        );
    }
  }
}

/// Cartographic custom painter rendering agricultural parcels, water bodies,
/// highway grid, and the day's authoritative 4px #016893 route line.
class _RouteCartographyPainter extends CustomPainter {
  _RouteCartographyPainter({
    required this.isSatellite,
    required this.showFlagExcludedRoute,
  });

  final bool isSatellite;
  final bool showFlagExcludedRoute;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 390.0;
    final scaleY = size.height / 506.0;

    // 1. Base Canvas
    final basePaint = Paint()
      ..color = isSatellite ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // 2. Farmland Plots / Green Zones
    final plotPaint1 = Paint()
      ..color = isSatellite ? const Color(0xFF1B3B2B) : const Color(0xFFEDF4ED);
    final plotPaint2 = Paint()
      ..color = isSatellite ? const Color(0xFF163324) : const Color(0xFFF1F8F1);
    final plotPaint3 = Paint()
      ..color = isSatellite ? const Color(0xFF1E4430) : const Color(0xFFF4F9F4);

    _drawPolygon(canvas, [
      Offset(12 * scaleX, 68 * scaleY),
      Offset(118 * scaleX, 52 * scaleY),
      Offset(142 * scaleX, 142 * scaleY),
      Offset(34 * scaleX, 168 * scaleY),
    ], plotPaint1);

    _drawPolygon(canvas, [
      Offset(152 * scaleX, 44 * scaleY),
      Offset(284 * scaleX, 36 * scaleY),
      Offset(298 * scaleX, 124 * scaleY),
      Offset(168 * scaleX, 138 * scaleY),
    ], plotPaint2);

    _drawPolygon(canvas, [
      Offset(308 * scaleX, 82 * scaleY),
      Offset(388 * scaleX, 74 * scaleY),
      Offset(388 * scaleX, 188 * scaleY),
      Offset(290 * scaleX, 174 * scaleY),
    ], plotPaint1);

    _drawPolygon(canvas, [
      Offset(40 * scaleX, 240 * scaleY),
      Offset(130 * scaleX, 224 * scaleY),
      Offset(144 * scaleX, 334 * scaleY),
      Offset(24 * scaleX, 352 * scaleY),
    ], plotPaint3);

    _drawPolygon(canvas, [
      Offset(154 * scaleX, 236 * scaleY),
      Offset(268 * scaleX, 228 * scaleY),
      Offset(280 * scaleX, 314 * scaleY),
      Offset(162 * scaleX, 328 * scaleY),
    ], plotPaint1);

    _drawPolygon(canvas, [
      Offset(288 * scaleX, 230 * scaleY),
      Offset(388 * scaleX, 218 * scaleY),
      Offset(388 * scaleX, 348 * scaleY),
      Offset(294 * scaleX, 360 * scaleY),
    ], plotPaint2);

    _drawPolygon(canvas, [
      Offset(56 * scaleX, 380 * scaleY),
      Offset(188 * scaleX, 370 * scaleY),
      Offset(178 * scaleX, 480 * scaleY),
      Offset(32 * scaleX, 476 * scaleY),
    ], plotPaint1);

    _drawPolygon(canvas, [
      Offset(204 * scaleX, 374 * scaleY),
      Offset(374 * scaleX, 368 * scaleY),
      Offset(368 * scaleX, 490 * scaleY),
      Offset(216 * scaleX, 494 * scaleY),
    ], plotPaint3);

    // 3. Godavari Tributary / Irrigation Canal
    final canalPaint = Paint()
      ..color = isSatellite ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    final canalPath = Path()
      ..moveTo(-20 * scaleX, 192 * scaleY)
      ..cubicTo(
        60 * scaleX,
        186 * scaleY,
        112 * scaleX,
        214 * scaleY,
        186 * scaleX,
        204 * scaleY,
      )
      ..cubicTo(
        256 * scaleX,
        194 * scaleY,
        318 * scaleX,
        162 * scaleY,
        410 * scaleX,
        172 * scaleY,
      );
    canvas.drawPath(canalPath, canalPaint);

    // 4. Minor Rural Road Network
    final roadPaint = Paint()
      ..color = isSatellite ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawLine(
      Offset(0, 84 * scaleY),
      Offset(size.width, 116 * scaleY),
      roadPaint,
    );
    canvas.drawLine(
      Offset(148 * scaleX, 0),
      Offset(168 * scaleX, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(284 * scaleX, 0),
      Offset(274 * scaleX, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, 364 * scaleY),
      Offset(size.width, 344 * scaleY),
      roadPaint,
    );

    // 5. Primary Arterial Highway (Dindori - Gangapur Link)
    final highwayCasing = Paint()
      ..color = isSatellite ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    final highwayCore = Paint()
      ..color = isSatellite ? const Color(0xFF475569) : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final highwayPath = Path()
      ..moveTo(38 * scaleX, size.height)
      ..cubicTo(
        42 * scaleX,
        420 * scaleY,
        54 * scaleX,
        340 * scaleY,
        76 * scaleX,
        268 * scaleY,
      )
      ..cubicTo(
        96 * scaleX,
        204 * scaleY,
        154 * scaleX,
        168 * scaleY,
        208 * scaleX,
        126 * scaleY,
      )
      ..cubicTo(
        268 * scaleX,
        78 * scaleY,
        322 * scaleX,
        46 * scaleY,
        364 * scaleX,
        0,
      );
    canvas.drawPath(highwayPath, highwayCasing);
    canvas.drawPath(highwayPath, highwayCore);

    // 6. Peri-Urban Sector Labels
    _drawLabel(
      canvas,
      'MAKHMALABAD',
      Offset(32 * scaleX, 106 * scaleY),
      isSatellite,
    );
    _drawLabel(
      canvas,
      'GANGAPUR',
      Offset(296 * scaleX, 68 * scaleY),
      isSatellite,
    );
    _drawLabel(
      canvas,
      'SHIVPURI BEAT',
      Offset(210 * scaleX, 274 * scaleY),
      isSatellite,
      isHighlighted: true,
    );
    _drawLabel(
      canvas,
      'Nashik Central Unit',
      Offset(26 * scaleX, 440 * scaleY),
      isSatellite,
    );

    // 7. Authoritative Full Day Route Polyline (4px #016893)
    final routePaint = Paint()
      ..color = AppColors.primary600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final routePath = Path()
      ..moveTo(58 * scaleX, 442 * scaleY)
      ..cubicTo(
        66 * scaleX,
        408 * scaleY,
        74 * scaleX,
        382 * scaleY,
        78 * scaleX,
        356 * scaleY,
      )
      ..cubicTo(
        84 * scaleX,
        318 * scaleY,
        96 * scaleX,
        294 * scaleY,
        116 * scaleX,
        280 * scaleY,
      )
      ..cubicTo(
        134 * scaleX,
        268 * scaleY,
        172 * scaleX,
        264 * scaleY,
        196 * scaleX,
        252 * scaleY,
      )
      ..cubicTo(
        214 * scaleX,
        244 * scaleY,
        228 * scaleX,
        244 * scaleY,
        236 * scaleX,
        242 * scaleY,
      )
      ..cubicTo(
        246 * scaleX,
        238 * scaleY,
        258 * scaleX,
        222 * scaleY,
        254 * scaleX,
        204 * scaleY,
      )
      ..cubicTo(
        250 * scaleX,
        188 * scaleY,
        232 * scaleX,
        176 * scaleY,
        218 * scaleX,
        168 * scaleY,
      )
      ..cubicTo(
        192 * scaleX,
        154 * scaleY,
        168 * scaleX,
        140 * scaleY,
        164 * scaleX,
        116 * scaleY,
      )
      ..cubicTo(
        160 * scaleX,
        92 * scaleY,
        186 * scaleX,
        78 * scaleY,
        214 * scaleX,
        74 * scaleY,
      )
      ..cubicTo(
        244 * scaleX,
        70 * scaleY,
        276 * scaleX,
        80 * scaleY,
        298 * scaleX,
        94 * scaleY,
      )
      ..cubicTo(
        314 * scaleX,
        104 * scaleY,
        326 * scaleX,
        102 * scaleY,
        336 * scaleX,
        92 * scaleY,
      );
    canvas.drawPath(routePath, routePaint);

    // 8. Flagged Anomaly Deviation (Dashed Red Segment #DC2626)
    if (showFlagExcludedRoute) {
      final flagPaint = Paint()
        ..color = AppColors.error
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      final flagPath = Path()
        ..moveTo(164 * scaleX, 116 * scaleY)
        ..cubicTo(
          146 * scaleX,
          110 * scaleY,
          134 * scaleX,
          94 * scaleY,
          138 * scaleX,
          80 * scaleY,
        )
        ..cubicTo(
          142 * scaleX,
          66 * scaleY,
          164 * scaleX,
          74 * scaleY,
          178 * scaleX,
          78 * scaleY,
        );

      _drawDashedPath(canvas, flagPath, flagPaint, 6.0, 4.0);
    }
  }

  void _drawPolygon(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset,
    bool isSatellite, {
    bool isHighlighted = false,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'DM Sans',
        fontSize: isHighlighted ? 9.5 : 8.5,
        fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
        letterSpacing: 0.5,
        color: isSatellite
            ? const Color(0xFF94A3B8)
            : (isHighlighted
                ? const Color(0xFF475569)
                : const Color(0xFF94A3B8)),
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dashWidth,
    double dashSpace,
  ) {
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        final extractPath = metric.extractPath(distance, distance + length);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RouteCartographyPainter oldDelegate) {
    return oldDelegate.isSatellite != isSatellite ||
        oldDelegate.showFlagExcludedRoute != showFlagExcludedRoute;
  }
}
