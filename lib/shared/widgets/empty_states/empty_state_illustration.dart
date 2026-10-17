import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'empty_state_type.dart';

/// 56x56 dp custom vector illustration with badge accents for Screen 28.
class EmptyStateIllustration extends StatelessWidget {
  const EmptyStateIllustration({super.key, required this.type});

  final EmptyStateType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.primary50,
        shape: BoxShape.circle,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          // Base Illustration
          _buildBaseIllustration(),

          // Corner Accent Badges
          if (type == EmptyStateType.noEmployees)
            Positioned(
              top: -2,
              right: -2,
              child: _buildBadge(icon: Icons.add, size: 20, iconSize: 13),
            ),
          if (type == EmptyStateType.noNotifications)
            Positioned(
              top: -2,
              right: -2,
              child: _buildBadge(icon: Icons.check, size: 20, iconSize: 13),
            ),
          if (type == EmptyStateType.routeExpired)
            Positioned(
              bottom: -2,
              right: -2,
              child: _buildBadge(icon: Icons.schedule, size: 22, iconSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required double size,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primary600,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: AppColors.surface),
    );
  }

  Widget _buildBaseIllustration() {
    return switch (type) {
      EmptyStateType.noEmployees => const _NoEmployeesPainterWidget(),
      EmptyStateType.nobodyOnDuty => const _NobodyOnDutyPainterWidget(),
      EmptyStateType.noNotifications => const Icon(
        Icons.notifications_none_rounded,
        size: 28,
        color: AppColors.neutral400,
      ),
      EmptyStateType.filteredToNothing => const _FilterNothingPainterWidget(),
      EmptyStateType.noRoute => const _NoRoutePainterWidget(),
      EmptyStateType.routeExpired => const Icon(
        Icons.calendar_month_outlined,
        size: 28,
        color: AppColors.neutral400,
      ),
    };
  }
}

// -----------------------------------------------------------------------------
// Custom Vector Painters for Screen 28 Illustrations
// -----------------------------------------------------------------------------

class _NoEmployeesPainterWidget extends StatelessWidget {
  const _NoEmployeesPainterWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: CustomPaint(painter: _NoEmployeesPainter()),
    );
  }
}

class _NoEmployeesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = AppColors.neutral400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final dashPaint = Paint()
      ..color = AppColors.neutral400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // Solid primary officer
    canvas.drawCircle(
      Offset(size.width * 0.38, size.height * 0.35),
      4.5,
      strokePaint,
    );
    final bodyPath = Path()
      ..moveTo(size.width * 0.16, size.height * 0.75)
      ..arcToPoint(
        Offset(size.width * 0.60, size.height * 0.75),
        radius: const Radius.circular(7),
        clockwise: false,
      );
    canvas.drawPath(bodyPath, strokePaint);

    // Dashed secondary officer
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.38),
      3.5,
      dashPaint,
    );
    final secondBodyPath = Path()
      ..moveTo(size.width * 0.66, size.height * 0.60)
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.62,
        size.width * 0.84,
        size.height * 0.78,
      );
    canvas.drawPath(secondBodyPath, dashPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NobodyOnDutyPainterWidget extends StatelessWidget {
  const _NobodyOnDutyPainterWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(painter: _NobodyOnDutyPainter()),
    );
  }
}

class _NobodyOnDutyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Outer dashed radar circle
    final radarPaint = Paint()
      ..color = AppColors.neutral400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const dashCount = 12;
    const radius = 14.0;
    for (var i = 0; i < dashCount; i++) {
      final angle = (i * 2 * math.pi) / dashCount;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        (2 * math.pi / dashCount) * 0.6,
        false,
        radarPaint,
      );
    }

    // Inner circle
    canvas.drawCircle(center, 7.5, radarPaint);

    // Pin silhouette
    final pinPath = Path()
      ..moveTo(center.dx, center.dy + 8)
      ..lineTo(center.dx - 5.5, center.dy - 1)
      ..arcToPoint(
        Offset(center.dx + 5.5, center.dy - 1),
        radius: const Radius.circular(5.5),
        clockwise: true,
      )
      ..close();

    final fillPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, fillPaint);
    canvas.drawPath(pinPath, radarPaint..strokeWidth = 1.3);

    // Center brand dot
    final dotPaint = Paint()
      ..color = AppColors.primary600
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, center.dy - 1), 2.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FilterNothingPainterWidget extends StatelessWidget {
  const _FilterNothingPainterWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: CustomPaint(painter: _FilterNothingPainter()),
    );
  }
}

class _FilterNothingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Funnel outline
    final funnelPaint = Paint()
      ..color = AppColors.neutral400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;

    final funnelPath = Path()
      ..moveTo(size.width * 0.16, size.height * 0.2)
      ..lineTo(size.width * 0.84, size.height * 0.2)
      ..lineTo(size.width * 0.58, size.height * 0.52)
      ..lineTo(size.width * 0.58, size.height * 0.80)
      ..lineTo(size.width * 0.42, size.height * 0.88)
      ..lineTo(size.width * 0.42, size.height * 0.52)
      ..close();
    canvas.drawPath(funnelPath, funnelPaint);

    // Diagonal slash in brand primary
    final slashPaint = Paint()
      ..color = AppColors.primary600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.82),
      Offset(size.width * 0.78, size.height * 0.18),
      slashPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NoRoutePainterWidget extends StatelessWidget {
  const _NoRoutePainterWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(painter: _NoRoutePainter()),
    );
  }
}

class _NoRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pathPaint = Paint()
      ..color = AppColors.neutral400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Curved route path
    final routePath = Path()
      ..moveTo(size.width * 0.20, size.height * 0.72)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.52,
        size.width * 0.45,
        size.height * 0.58,
        size.width * 0.52,
        size.height * 0.44,
      )
      ..cubicTo(
        size.width * 0.60,
        size.height * 0.30,
        size.width * 0.70,
        size.height * 0.36,
        size.width * 0.78,
        size.height * 0.22,
      );
    canvas.drawPath(routePath, pathPaint);

    // Start point circle
    final startPaint = Paint()
      ..color = AppColors.neutral400
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.20, size.height * 0.72),
      2.5,
      startPaint,
    );

    // End node circle in brand primary with ?
    final endNodePaint = Paint()
      ..color = AppColors.primary600
      ..style = PaintingStyle.fill;
    final endCenter = Offset(size.width * 0.78, size.height * 0.22);
    canvas.drawCircle(endCenter, 5.5, endNodePaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          color: AppColors.surface,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        endCenter.dx - textPainter.width / 2,
        endCenter.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
