import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Upper 55% dynamic geofence map canvas for Screen 25 Create / Edit Place (Admin).
class AdminPlaceGeofenceMap extends StatelessWidget {
  const AdminPlaceGeofenceMap({
    super.key,
    required this.radiusMeters,
    required this.adjacentPlaceName,
    required this.adjacentDistanceMeters,
    required this.onToggleLayers,
    this.isSatellite = false,
  });

  final double radiusMeters;
  final String adjacentPlaceName;
  final int adjacentDistanceMeters;
  final VoidCallback onToggleLayers;
  final bool isSatellite;

  @override
  Widget build(BuildContext context) {
    // Dynamic circle diameter based on radius:
    // Base 500m -> 260dp. Range: 100dp (50m) to 360dp (2000m)
    final circleDiameter = (100.0 + (radiusMeters - 50.0) / (2000.0 - 50.0) * 260.0)
        .clamp(90.0, 360.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          key: const Key('admin-place-geofence-map'),
          children: <Widget>[
            // 1. Regional Street Map Custom Painter
            Positioned.fill(
              child: CustomPaint(
                painter: _StreetGeofencePainter(isSatellite: isSatellite),
              ),
            ),

            // 2. Overlapping Adjacent Registered Entity (Top-Right)
            Positioned(
              right: 16,
              top: 54,
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Dashed adjacent circle
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.neutral400.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.neutral400,
                          width: 1.5,
                          style: BorderStyle.solid,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.neutral500,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Chip Tag for adjacent entity
                    Container(
                      key: const Key('adjacent-geofence-badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: AppColors.neutral200,
                          width: 1,
                        ),
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
                        children: <Widget>[
                          const Icon(
                            Icons.storefront_rounded,
                            size: 13,
                            color: AppColors.neutral500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$adjacentPlaceName — $adjacentDistanceMeters m away',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.neutral600,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Active Geofence Area (Centered)
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Scaled Translucent Geofence Circle
                  Container(
                    width: circleDiameter,
                    height: circleDiameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary600.withValues(alpha: 0.18),
                      border: Border.all(
                        color: AppColors.primary600,
                        width: 2.0,
                      ),
                    ),
                  ),

                  // Floating Metric Indicator Chip (At top edge of circle)
                  Positioned(
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary600,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x20016893),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        '${radiusMeters.round()} m Radius',
                        style: AppTypography.overline.copyWith(
                          color: AppColors.neutral0,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Center 40px Brand Location Pin
                  Positioned(
                    bottom: (circleDiameter / 2) - 4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Pin Icon
                        Container(
                          key: const Key('center-geofence-pin'),
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppColors.primary600,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x25000000),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.neutral0,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Ground contact indicator
                        Container(
                          width: 12,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 4. Scale Bar (Bottom-Left)
            Positioned(
              left: AppSpacing.x4,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.neutral200,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '500 m',
                      key: const Key('scale-bar-text'),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral600,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 48,
                      height: 2,
                      decoration: const BoxDecoration(
                        color: AppColors.neutral600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. OpenStreetMap Attribution (Center-Bottom)
            Positioned(
              left: 74,
              bottom: 14,
              child: Text(
                '© OpenStreetMap contributors',
                style: AppTypography.overline.copyWith(
                  color: AppColors.neutral500,
                  fontSize: 10,
                ),
              ),
            ),

            // 6. Floating Layer Toggle Button (Bottom-Right)
            Positioned(
              right: AppSpacing.x4,
              bottom: 10,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.neutral200, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('btn-toggle-map-layer'),
                    onTap: onToggleLayers,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: Icon(
                      Icons.layers_outlined,
                      size: 20,
                      color: isSatellite
                          ? AppColors.primary600
                          : AppColors.neutral600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Custom painter rendering rural street geometry and canal network.
class _StreetGeofencePainter extends CustomPainter {
  _StreetGeofencePainter({required this.isSatellite});

  final bool isSatellite;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Base Landfill
    final landPaint = Paint()
      ..color = isSatellite ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    // 2. Rural Agricultural Plots
    final plotPaint1 = Paint()
      ..color = isSatellite ? const Color(0xFF1B3B2B) : const Color(0xFFE8F0E8);
    final plotPaint2 = Paint()
      ..color = isSatellite ? const Color(0xFF163324) : const Color(0xFFEDF5ED);

    canvas.drawRect(
      Rect.fromLTWH(10, 20, size.width * 0.4, size.height * 0.35),
      plotPaint1,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.55,
        size.height * 0.45,
        size.width * 0.4,
        size.height * 0.45,
      ),
      plotPaint2,
    );

    // 3. Stream / Canal (Soft #C5E1EC)
    final streamPaint = Paint()
      ..color = isSatellite ? const Color(0xFF0369A1) : const Color(0xFFC5E1EC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final streamPath = Path()
      ..moveTo(0, size.height * 0.75)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.70,
        size.width * 0.6,
        size.height * 0.85,
        size.width,
        size.height * 0.78,
      );
    canvas.drawPath(streamPath, streamPaint);

    // 4. White Rural Roads Network
    final roadCasing = Paint()
      ..color = isSatellite ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    final roadCore = Paint()
      ..color = isSatellite ? const Color(0xFF334155) : const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final mainRoad = Path()
      ..moveTo(size.width * 0.15, 0)
      ..cubicTo(
        size.width * 0.20,
        size.height * 0.4,
        size.width * 0.75,
        size.height * 0.6,
        size.width * 0.85,
        size.height,
      );
    canvas.drawPath(mainRoad, roadCasing);
    canvas.drawPath(mainRoad, roadCore);

    final crossRoad = Path()
      ..moveTo(0, size.height * 0.45)
      ..lineTo(size.width, size.height * 0.38);
    canvas.drawPath(crossRoad, roadCasing);
    canvas.drawPath(crossRoad, roadCore);
  }

  @override
  bool shouldRepaint(covariant _StreetGeofencePainter oldDelegate) {
    return oldDelegate.isSatellite != isSatellite;
  }
}
