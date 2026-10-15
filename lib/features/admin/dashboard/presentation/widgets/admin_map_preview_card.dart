import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Card 3 — Live Map preview thumbnail displaying regional field officer positions
/// and clustering adhering strictly to Screen 14 design specifications.
class AdminMapPreviewCard extends StatelessWidget {
  const AdminMapPreviewCard({
    super.key,
    required this.onViewMap,
  });

  final VoidCallback onViewMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Row
          InkWell(
            onTap: onViewMap,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      Text(
                        'Live map',
                        style: AppTypography.title.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'View all',
                        style: AppTypography.label.copyWith(
                          color: AppColors.primary600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.primary600,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Map Preview Canvas (180 dp tall)
          InkWell(
            key: const Key('admin-live-map-preview-tap'),
            onTap: onViewMap,
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                children: [
                  // 1. Topographic Map Background Painter
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _AdminTopographyPainter(),
                    ),
                  ),

                  // 2. Hub Label Badge (Top-Left)
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: AppRadius.smAll,
                        border: Border.all(color: AppColors.neutral200),
                      ),
                      child: Text(
                        'NASHIK RURAL HUB',
                        style: AppTypography.overline.copyWith(
                          fontSize: 9,
                          letterSpacing: 0.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // 3. Scattered On-Duty Officers (Green Markers)
                  _buildMarker(top: 32, left: 68, color: AppColors.success),
                  _buildMarker(top: 52, left: 110, color: AppColors.success),
                  _buildMarker(top: 82, left: 45, color: AppColors.success),
                  _buildMarker(top: 112, left: 88, color: AppColors.success),
                  _buildMarker(top: 140, left: 130, color: AppColors.success),
                  _buildMarker(top: 28, right: 125, color: AppColors.success),
                  _buildMarker(top: 68, right: 75, color: AppColors.success),
                  _buildMarker(top: 95, right: 110, color: AppColors.success),
                  _buildMarker(top: 125, right: 55, color: AppColors.success),
                  _buildMarker(top: 148, right: 145, color: AppColors.success),
                  _buildMarker(top: 18, left: 175, color: AppColors.success),

                  // 4. Amber Warning Markers (Stale)
                  _buildMarker(top: 102, left: 165, color: AppColors.warning),
                  _buildMarker(top: 42, right: 40, color: AppColors.warning),

                  // 5. Red Alert Marker (Suspect)
                  _buildMarker(
                    top: 76,
                    left: 205,
                    color: AppColors.error,
                    size: 14,
                  ),

                  // 6. Cluster 1: 12 Officers (Nashik Central)
                  Positioned(
                    top: 50,
                    left: 135,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '12',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),

                  // 7. Cluster 2: 8 Officers (Deolali Belt)
                  Positioned(
                    bottom: 36,
                    right: 85,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '8',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),

                  // 8. GPS Accuracy Pill (Bottom-Left)
                  Positioned(
                    bottom: 8,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: AppRadius.smAll,
                        border: Border.all(color: AppColors.neutral200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.my_location_rounded,
                            size: 12,
                            color: AppColors.primary600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '98.4% Acc.',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 9. Legal Map Attribution (Bottom-Right)
                  Positioned(
                    bottom: 6,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Mapbox © OpenStreetMap',
                        style: AppTypography.caption.copyWith(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarker({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required Color color,
    double size = 12,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter generating realistic cartographic background topography
/// (farmland grids, river waterways, and highway arterials).
class _AdminTopographyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Land Background
    final landPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    // 2. Farmland Grid Lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (double y = 45; y < size.height; y += 45) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 90; x < size.width; x += 90) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // 3. River Waterway
    final riverOuterPaint = Paint()
      ..color = const Color(0xFFC5E1EC)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final riverInnerPaint = Paint()
      ..color = const Color(0xFFE0F2FE)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final riverPath = Path()
      ..moveTo(-10, 30)
      ..quadraticBezierTo(size.width * 0.25, 65, size.width * 0.45, 50)
      ..quadraticBezierTo(size.width * 0.75, 75, size.width + 20, 40);

    canvas.drawPath(riverPath, riverOuterPaint);
    canvas.drawPath(riverPath, riverInnerPaint);

    // 4. Arterial Highway Network (White with subtle casing)
    final highwayCasingPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final highwayCorePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final highway1 = Path()
      ..moveTo(size.width * 0.12, -10)
      ..lineTo(size.width * 0.55, size.height + 10);

    canvas.drawPath(highway1, highwayCasingPaint);
    canvas.drawPath(highway1, highwayCorePaint);

    final highway2 = Path()
      ..moveTo(-10, 130)
      ..quadraticBezierTo(size.width * 0.35, 110, size.width * 0.70, 140)
      ..lineTo(size.width + 10, 120);

    canvas.drawPath(highway2, highwayCasingPaint);
    canvas.drawPath(highway2, highwayCorePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
