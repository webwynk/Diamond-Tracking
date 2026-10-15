import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_live_map_state.dart';

/// Single interactive officer marker on the administrative map.
class AdminMapOfficerMarker extends StatefulWidget {
  const AdminMapOfficerMarker({
    super.key,
    required this.officer,
    required this.onTap,
    this.isSelected = false,
  });

  final MapOfficerItem officer;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  State<AdminMapOfficerMarker> createState() => _AdminMapOfficerMarkerState();
}

class _AdminMapOfficerMarkerState extends State<AdminMapOfficerMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    );
    if (widget.officer.isSos ||
        widget.officer.status == AdminOfficerStatus.needsCheck) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(AdminMapOfficerMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.officer.isSos ||
        widget.officer.status == AdminOfficerStatus.needsCheck) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getMarkerColor() {
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

  IconData _getMarkerIcon() {
    switch (widget.officer.status) {
      case AdminOfficerStatus.onDuty:
        return Icons.person_rounded;
      case AdminOfficerStatus.stale:
        return Icons.signal_cellular_nodata_rounded;
      case AdminOfficerStatus.needsCheck:
        return Icons.warning_rounded;
      case AdminOfficerStatus.offDuty:
        return Icons.person_off_rounded;
      case AdminOfficerStatus.blocked:
        return Icons.block_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = widget.officer.isSos ||
        widget.officer.status == AdminOfficerStatus.needsCheck;
    final markerColor = _getMarkerColor();
    final markerSize = isCritical ? 40.0 : 32.0;

    return GestureDetector(
      key: Key('marker-officer-${widget.officer.id}'),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. Pulsing halo ring for SOS / Critical
          if (isCritical)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale = 1.0 + (_pulseAnimation.value * 0.5);
                final opacity = (1.0 - _pulseAnimation.value).clamp(0.0, 1.0);
                return Container(
                  width: 48 * scale,
                  height: 48 * scale,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: opacity * 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: opacity * 0.6),
                      width: 1.5,
                    ),
                  ),
                );
              },
            ),

          // 2. Base Marker Circle
          Container(
            width: markerSize,
            height: markerSize,
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: markerColor.withValues(alpha: 0.4),
                  blurRadius: isCritical ? 10 : 6,
                  offset: const Offset(0, 2),
                ),
                if (widget.isSelected)
                  const BoxShadow(
                    color: AppColors.primary600,
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              _getMarkerIcon(),
              size: isCritical ? 20 : 17,
              color: Colors.white,
            ),
          ),

          // 3. SOS Tooltip Pill if present
          if (widget.officer.sosTag != null)
            Positioned(
              top: markerSize + 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.neutral200),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  widget.officer.sosTag!,
                  style: AppTypography.caption.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Aggregated regional cluster bubble widget.
class AdminMapClusterBubble extends StatelessWidget {
  const AdminMapClusterBubble({
    super.key,
    required this.cluster,
    required this.onTap,
  });

  final MapClusterItem cluster;
  final VoidCallback onTap;

  Color _getClusterColor() {
    switch (cluster.dominantStatus) {
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
    final color = _getClusterColor();

    return GestureDetector(
      key: Key('cluster-${cluster.id}'),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          cluster.count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
