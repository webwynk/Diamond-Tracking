import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// Pattern 6: Realtime Disconnected Strip.
///
/// Thin subtle ambient notification indicating live fleet WebSocket reconnection.
class RealtimeDisconnectedStrip extends StatefulWidget {
  const RealtimeDisconnectedStrip({
    super.key,
    this.label = 'Reconnecting…',
    this.isSpinning = true,
  });

  final String label;
  final bool isSpinning;

  @override
  State<RealtimeDisconnectedStrip> createState() =>
      _RealtimeDisconnectedStripState();
}

class _RealtimeDisconnectedStripState extends State<RealtimeDisconnectedStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isSpinning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RealtimeDisconnectedStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpinning != oldWidget.isSpinning) {
      if (widget.isSpinning) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('strip-realtime-disconnected'),
      height: 32,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          RotationTransition(
            turns: _controller,
            child: const Icon(Icons.sync, size: 16, color: AppColors.warning),
          ),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: AppTypography.caption.copyWith(
              color: AppColors.warningText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
