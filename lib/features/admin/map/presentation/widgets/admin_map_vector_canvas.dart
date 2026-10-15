import 'package:flutter/material.dart';

import '../controllers/admin_live_map_state.dart';
import 'admin_map_marker_widget.dart';

/// Regional cartographic vector canvas rendering Maharashtra Nashik Basin
/// geography and interactive telemetry markers.
class AdminMapVectorCanvas extends StatelessWidget {
  const AdminMapVectorCanvas({
    super.key,
    required this.officers,
    required this.clusters,
    required this.onOfficerTapped,
    required this.onClusterTapped,
    this.selectedOfficerId,
    this.isSatellite = false,
  });

  final List<MapOfficerItem> officers;
  final List<MapClusterItem> clusters;
  final ValueChanged<MapOfficerItem> onOfficerTapped;
  final ValueChanged<MapClusterItem> onClusterTapped;
  final String? selectedOfficerId;
  final bool isSatellite;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          children: [
            // 1. Regional Topography Custom Painter
            Positioned.fill(
              child: CustomPaint(
                painter: _RegionalTopographyPainter(isSatellite: isSatellite),
              ),
            ),

            // 2. Cluster Bubbles Layer
            ...clusters.map((cluster) {
              final x = cluster.relativeX * width;
              final y = cluster.relativeY * height;

              return Positioned(
                left: x - 24, // 48dp diameter / 2
                top: y - 24,
                child: AdminMapClusterBubble(
                  cluster: cluster,
                  onTap: () => onClusterTapped(cluster),
                ),
              );
            }),

            // 3. Individual Officer Markers Layer
            ...officers.map((officer) {
              final isCritical = officer.isSos ||
                  officer.status == AdminOfficerStatus.needsCheck;
              final markerRadius = isCritical ? 20.0 : 16.0;
              final x = officer.relativeX * width;
              final y = officer.relativeY * height;

              return Positioned(
                left: x - markerRadius,
                top: y - markerRadius,
                child: AdminMapOfficerMarker(
                  officer: officer,
                  isSelected: officer.id == selectedOfficerId,
                  onTap: () => onOfficerTapped(officer),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _RegionalTopographyPainter extends CustomPainter {
  const _RegionalTopographyPainter({this.isSatellite = false});

  final bool isSatellite;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Background Land
    final landColor =
        isSatellite ? const Color(0xFF263238) : const Color(0xFFF1F5F9);
    final bgPaint = Paint()..color = landColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 2. Farmland parcel grid (subtle dotted lines)
    final gridPaint = Paint()
      ..color = isSatellite
          ? const Color(0xFF37474F).withValues(alpha: 0.6)
          : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const gridStep = 45.0;
    for (double y = gridStep; y < h; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    for (double x = gridStep; x < w; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    // 3. Water Systems (Godavari River Tributary & Niphad Reservoirs)
    final waterColor =
        isSatellite ? const Color(0xFF1E3A8A) : const Color(0xFFC5E1EC);
    final riverPaint = Paint()
      ..color = waterColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final riverPath = Path()
      ..moveTo(0, h * 0.32)
      ..cubicTo(
        w * 0.25,
        h * 0.35,
        w * 0.45,
        h * 0.28,
        w * 0.65,
        h * 0.32,
      )
      ..cubicTo(
        w * 0.85,
        h * 0.36,
        w * 0.95,
        h * 0.30,
        w,
        h * 0.34,
      )
      ..lineTo(w, h * 0.38)
      ..cubicTo(
        w * 0.85,
        h * 0.41,
        w * 0.65,
        h * 0.36,
        w * 0.45,
        h * 0.40,
      )
      ..cubicTo(
        w * 0.25,
        h * 0.38,
        w * 0.1,
        h * 0.44,
        0,
        h * 0.39,
      )
      ..close();
    canvas.drawPath(riverPath, riverPaint);

    // Tributary Branch
    final tributaryPaint = Paint()
      ..color = waterColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final branchPath = Path()
      ..moveTo(w * 0.48, h * 0.34)
      ..cubicTo(
        w * 0.55,
        h * 0.45,
        w * 0.62,
        h * 0.58,
        w * 0.74,
        h * 0.65,
      )
      ..cubicTo(
        w * 0.82,
        h * 0.70,
        w * 0.9,
        h * 0.72,
        w,
        h * 0.74,
      );
    canvas.drawPath(branchPath, tributaryPaint);

    // Reservoirs / Lakes
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.8, h * 0.22),
        width: 60,
        height: 36,
      ),
      riverPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.25, h * 0.88),
        width: 52,
        height: 28,
      ),
      riverPaint,
    );

    // 4. Major Highways (NH-60 Arterial Corridors in Crisp White / Light Tone)
    final roadColor =
        isSatellite ? const Color(0xFFE2E8F0) : const Color(0xFFFFFFFF);
    final highwayPaint = Paint()
      ..color = roadColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.square;

    // Diagonal arterial
    canvas.drawLine(
      Offset(-10, h * 0.2),
      Offset(w + 10, h * 0.52),
      highwayPaint,
    );
    // Vertical corridor
    canvas.drawLine(
      Offset(w * 0.25, -10),
      Offset(w * 0.42, h + 10),
      highwayPaint,
    );
    // Cross regional connector
    canvas.drawLine(
      Offset(-10, h * 0.7),
      Offset(w + 10, h * 0.62),
      highwayPaint,
    );

    // 5. Secondary Rural Roads & Agritech Connectors
    final secondaryRoadPaint = Paint()
      ..color = roadColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final farmPath1 = Path()
      ..moveTo(w * 0.05, h * 0.08)
      ..quadraticBezierTo(w * 0.3, h * 0.14, w * 0.5, h * 0.09)
      ..quadraticBezierTo(w * 0.75, h * 0.06, w * 0.95, h * 0.12);
    canvas.drawPath(farmPath1, secondaryRoadPaint);

    final farmPath2 = Path()
      ..moveTo(w * 0.12, h * 0.48)
      ..quadraticBezierTo(w * 0.35, h * 0.54, w * 0.58, h * 0.46)
      ..quadraticBezierTo(w * 0.8, h * 0.56, w * 0.96, h * 0.52);
    canvas.drawPath(farmPath2, secondaryRoadPaint);

    final farmPath3 = Path()
      ..moveTo(w * 0.08, h * 0.85)
      ..quadraticBezierTo(w * 0.32, h * 0.78, w * 0.6, h * 0.84)
      ..quadraticBezierTo(w * 0.82, h * 0.80, w * 0.98, h * 0.88);
    canvas.drawPath(farmPath3, secondaryRoadPaint);

    // 6. Regional Taluka Boundaries (Subtle Dash)
    final boundaryPaint = Paint()
      ..color = isSatellite ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw dashed lines
    _drawDashedLine(
      canvas,
      Offset(w * 0.34, 0),
      Offset(w * 0.4, h),
      boundaryPaint,
    );
    _drawDashedLine(
      canvas,
      Offset(w * 0.72, 0),
      Offset(w * 0.65, h),
      boundaryPaint,
    );
    _drawDashedLine(
      canvas,
      Offset(0, h * 0.54),
      Offset(w, h * 0.52),
      boundaryPaint,
    );

    // 7. Cartographic Geographic Area Labels
    _drawAreaLabel(
      canvas: canvas,
      title: 'DINDORI',
      subtitle: 'TALUKA NORTH',
      offset: Offset(w * 0.16, h * 0.14),
    );
    _drawAreaLabel(
      canvas: canvas,
      title: 'NIPHAD',
      subtitle: 'GRAPE BASIN SUB-DIV',
      offset: Offset(w * 0.68, h * 0.18),
    );
    _drawAreaLabel(
      canvas: canvas,
      title: 'NASHIK RURAL',
      subtitle: 'CENTRAL DISPATCH HQ',
      offset: Offset(w * 0.12, h * 0.42),
      isMajor: true,
    );
    _drawAreaLabel(
      canvas: canvas,
      title: 'DEOLALI',
      subtitle: 'CANTONMENT SECTOR',
      offset: Offset(w * 0.35, h * 0.58),
    );
    _drawAreaLabel(
      canvas: canvas,
      title: 'SINNAR',
      subtitle: 'INDUSTRIAL & AGRONOMY',
      offset: Offset(w * 0.62, h * 0.76),
      isMajor: true,
    );
    _drawAreaLabel(
      canvas: canvas,
      title: 'TRIMBAK',
      subtitle: 'WESTERN GHATS RANGE',
      offset: Offset(w * 0.08, h * 0.8),
    );
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final totalDistance = (p2 - p1).distance;
    final unitVector = (p2 - p1) / totalDistance;

    double currentDistance = 0.0;
    while (currentDistance < totalDistance) {
      final start = p1 + unitVector * currentDistance;
      final remaining = totalDistance - currentDistance;
      final step = remaining < dashWidth ? remaining : dashWidth;
      final end = start + unitVector * step;
      canvas.drawLine(start, end, paint);
      currentDistance += dashWidth + dashSpace;
    }
  }

  void _drawAreaLabel({
    required Canvas canvas,
    required String title,
    required String subtitle,
    required Offset offset,
    bool isMajor = false,
  }) {
    final titleColor = isSatellite
        ? const Color(0xFFE2E8F0)
        : (isMajor ? const Color(0xFF334155) : const Color(0xFF64748B));
    final subColor =
        isSatellite ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: isMajor ? 13 : 11,
          fontWeight: isMajor ? FontWeight.w700 : FontWeight.w600,
          letterSpacing: isMajor ? 1.4 : 1.0,
          color: titleColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final subPainter = TextPainter(
      text: TextSpan(
        text: subtitle,
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 8.5,
          fontWeight: FontWeight.w500,
          color: subColor,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    titlePainter.paint(canvas, offset);
    subPainter.paint(canvas, Offset(offset.dx, offset.dy + titlePainter.height));
  }

  @override
  bool shouldRepaint(covariant _RegionalTopographyPainter oldDelegate) {
    return oldDelegate.isSatellite != isSatellite;
  }
}
